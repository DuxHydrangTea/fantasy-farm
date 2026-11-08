class_name FarmDebugCommands
extends RefCounted
signal clear_requested
signal perf_changed(enabled: bool)
var world: FarmWorld
var registry: DebugCommandRegistry = DebugCommandRegistry.new()
var catalog: SaveCatalog
var busy: bool = false

func _init(farm: FarmWorld) -> void:
	world = farm
	_bind("help", "help [command]", "Command reference", _help)
	_bind("clear", "clear", "Clear console output", _clear)
	_bind("find", "find <item|crop|animal> <query>", "Search catalog IDs", _find)
	_bind("inspect", "inspect here", "Inspect nearest animal or field cell", _inspect)
	_bind("pos", "pos", "Player pixels and farmland cell", _pos)
	_bind("money", "money <get|add|set> [amount]", "Read or change coins", _money)
	_bind("give", "give <item> [count=1] [normal|silver|gold]", "Add to player bag", _give, true)
	_bind("storage", "storage <info [id]|add id item count [quality]>", "Inspect or supply warehouses", _storage)
	_bind("tp", "tp <x y|workers|farm|coop|barn|pond|orders>", "Teleport player in world pixels", _tp, true)
	_bind("time", "time <get|hour 0-23|hour auto|advance count second|minute|hour|day>", "Lighting preview or full simulation", _time)
	_bind("weather", "weather <set sunny|rain|cloudy|windy|auto>", "Weather override for today", _weather, true)
	_bind("crop", "crop <info|grow|water|disease pests|weeds|clear> [here|x y|all confirm]", "Inspect or modify field crops", _crop)
	_bind("land unlock", "land unlock <1-24>", "Set unlocked block count (expansion only)", _land, true)
	_bind("animal", "animal <list [species]|info id|spawn species [count]|disease id on|off|needs id food|water 0-100|age id young|adult>", "Animal IDs also accept here", _animal)
	_bind("worker", "worker <list|info id|target id|hire|pause id|all|resume id|all|upgrade track level>", "Team operations; IDs or slot numbers", _worker)
	_bind("upgrade", "upgrade <tool id level|pen id level>", "Set debug upgrade level", _upgrade, true)
	_bind("objective", "objective <list|complete id>", "Complete active objective, then claim reward normally", _objective)
	_bind("order list", "order list", "Current order state", _orders)
	_bind("save", "save <status|validate>", "Inspect live state and primary/backup validation", _save)
	_bind("perf", "perf <on|off|snapshot>", "Frame and worker CPU diagnostics", _perf)

func _bind(path: String, usage: String, description: String, handler: Callable, write: bool = false) -> void:
	registry.register(path, usage, description, handler, write)

func ok(value: Variant = "OK") -> Dictionary:
	return {"ok": true, "text": value if value is String else JSON.stringify(value, "  ")}

func fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func resources() -> SaveCatalog:
	if catalog == null:
		catalog = SaveCatalog.new()
	return catalog

func execute(line: String) -> Dictionary:
	if not OS.is_debug_build():
		return fail("Debug commands are disabled in release builds.")
	if busy or world.workers.busy or world.storages.busy or SaveManager.busy:
		return fail("A world operation is in progress.")
	var parsed: Dictionary = DebugCommandRegistry.parse(line)
	if not parsed.ok:
		return parsed
	var command: Dictionary = registry.resolve(parsed.tokens)
	if command.is_empty():
		return fail("Unknown command. Use /help.")
	if not world.tool_upgrades.profile_ready and command.path not in ["help", "clear", "find", "pos", "save"]:
		return fail("Wait until the farm profile has loaded.")
	busy = true
	var result: Dictionary = await command.handler.call(command.args)
	busy = false
	if not result.ok and not result.has("error"):
		result["error"] = "Operation was rejected. Check /help " + command.path
	return result

func _help(args: Array) -> Dictionary:
	var text: String = registry.help_text(" ".join(args))
	return ok(text) if not text.is_empty() else fail("No matching commands.")

func _clear(args: Array) -> Dictionary:
	if not args.is_empty(): return fail("Usage: /clear")
	clear_requested.emit()
	return ok("")

func _find(args: Array) -> Dictionary:
	if args.size() < 2: return fail("Usage: /find item|crop|animal query")
	if args[0] not in ["item", "crop", "animal"]: return fail("Catalog must be item, crop or animal.")
	var data: Dictionary = resources().items if args[0] == "item" else resources().crops if args[0] == "crop" else resources().animals if args[0] == "animal" else {}
	var query: String = " ".join(args.slice(1)).to_lower()
	var matches: Array[String] = []
	for id: String in data:
		if id.to_lower().contains(query): matches.append(id)
	matches.sort()
	return ok(matches)

func _pos(_args: Array) -> Dictionary:
	return ok({"pixels": str(world.player.global_position), "cell": str(world.farming.world_to_cell(world.player.global_position))})

func _inspect(args: Array) -> Dictionary:
	if args != ["here"]: return fail("Usage: /inspect here")
	var animal: AnimalActor = _animal_target("here")
	if animal != null: return ok(_animal_info(animal))
	return _crop(["info", "here"])

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	var text: String = str(value)
	return text.is_valid_int() and text.length() < 16 and int(text) >= minimum and int(text) <= maximum

func _money(args: Array) -> Dictionary:
	if args == ["get"]: return ok(world.player.wallet.balance)
	if args.size() != 2 or args[0] not in ["set", "add"] or not _integer(args[1], -WalletComponent.MAX_COINS, WalletComponent.MAX_COINS): return fail("Usage: /money get|set amount|add amount")
	world.workers.settle(world.farming.time_manager.now())
	var amount: int = int(args[1]) + (world.player.wallet.balance if args[0] == "add" else 0)
	if amount < 0 or amount > WalletComponent.MAX_COINS: return fail("Coin balance out of range.")
	world.player.wallet.set_balance(amount)
	return ok(world.player.wallet.balance)

func _quality(args: Array, index: int) -> int:
	return ["normal", "silver", "gold"].find(str(args[index]).to_lower()) if args.size() > index else 0

func _add(bag: InventoryComponent, id: String, amount: Variant, tier: int) -> Dictionary:
	var item: ItemDefinition = resources().items.get(id) as ItemDefinition
	if item == null or not _integer(amount, 1, 1000000) or tier < 0: return fail("Invalid item, count or quality. Use /find item query.")
	if not ItemQuality.supported(item, tier): return fail("This item does not support that quality.")
	if bag.capacity_for(item, tier) < int(amount): return fail("Inventory cannot accept the full quantity.")
	return ok({"accepted": bag.add(item, int(amount), tier), "item": id})

func _give(args: Array) -> Dictionary:
	if args.is_empty() or args.size() > 3: return fail("Usage: /give item [count] [quality]")
	return _add(world.player.selection.inventory, args[0], args[1] if args.size() > 1 else "1", _quality(args, 2))

func _storage_id(id: String) -> String:
	return "farm_supply_storage" if id == "supply" else "produce_warehouse" if id == "produce" else id

func _storage(args: Array) -> Dictionary:
	if args.is_empty(): return fail("Usage: /storage info [id] | add id item count [quality]")
	if args[0] == "info" and args.size() <= 2:
		var data: Dictionary = world.storages.capture()
		return ok(data.get(_storage_id(args[1]), {})) if args.size() == 2 else ok(data)
	if args[0] != "add" or args.size() not in [4, 5]: return fail("Usage: /storage add supply|produce item count [quality]")
	var id: String = _storage_id(args[1])
	if not world.storages.inventories.has(id): return fail("Unknown warehouse.")
	var item: ItemDefinition = resources().items.get(args[2]) as ItemDefinition
	if item == null or not world.storages.definition(id).accepts(item): return fail("This warehouse does not accept that item.")
	return _add(world.storages.inventory(id), args[2], args[3], _quality(args, 4))

func _tp(args: Array) -> Dictionary:
	var point: Vector2
	if args.size() == 2 and str(args[0]).is_valid_float() and str(args[1]).is_valid_float():
		point = Vector2(float(args[0]), float(args[1]))
	else:
		var locations: Dictionary = {"workers": "CropWorkers", "coop": "CoopPen", "barn": "BarnPen", "pond": "PondPen", "orders": "OrderBoard"}
		if args == ["farm"]:
			point = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(54, 24)))
		elif args.size() == 1 and locations.has(args[0]):
			point = (world.get_node(locations[args[0]]) as Node2D).global_position + Vector2(0, 48)
		else: return fail("Usage: /tp x y | workers|farm|coop|barn|pond|orders")
	var camera: Camera2D = world.player.camera
	if not point.is_finite() or not Rect2(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top).has_point(point): return fail("Position is outside the world.")
	world.player.velocity = Vector2.ZERO
	world.player.global_position = point
	world.player.camera.reset_smoothing()
	return _pos([])

func _time(args: Array) -> Dictionary:
	var clock: FarmClock = world.farming.time_manager
	if args == ["get"]: return ok({"simulation": clock.now(), "display": world.weather.display_timestamp(clock.now())})
	if args.size() == 2 and args[0] == "hour" and (args[1] == "auto" or _integer(args[1], 0, 23)):
		world.weather.set_debug_hour(-1 if args[1] == "auto" else int(args[1]))
		return ok({"simulation": clock.now(), "display": world.weather.display_timestamp(clock.now())})
	var units: Dictionary = {"second": 1, "minute": 60, "hour": 3600, "day": 86400}
	if args.size() != 3 or args[0] != "advance" or not _integer(args[1], 1, 604800) or not units.has(args[2]): return fail("Usage: /time get|hour 0-23|hour auto|advance count second|minute|hour|day")
	var seconds: float = float(args[1]) * float(units[args[2]])
	if seconds > 604800: return fail("Maximum advance is 7 days per command.")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, resources())
	var snapshot: Dictionary = adapter.capture("debug", 1, clock.now())
	var checked: Dictionary = SaveSchema.validate(snapshot, resources())
	if not checked.ok: return fail(str(checked))
	var target: float = clock.now() + seconds
	var result: Dictionary = await adapter.restore_async(checked.snapshot, target)
	if result.ok: clock.begin_session(target)
	return ok({"advanced_seconds": seconds, "timestamp": target}) if result.ok else fail(str(result))

func _weather(args: Array) -> Dictionary:
	var names: Array[String] = ["sunny", "rain", "cloudy", "windy"]
	if args == ["auto"]:
		var schedule: WeatherSchedule = WeatherSchedule.new()
		schedule.seed = world.weather.schedule.seed
		world.weather.set_weather(schedule.weather_at(world.farming.time_manager.now()))
		return ok("Automatic daily weather restored for today.")
	if args.size() != 2 or args[0] != "set" or not names.has(args[1]): return fail("Usage: /weather set sunny|rain|cloudy|windy | auto")
	world.weather.set_weather(names.find(args[1]) as WeatherSchedule.Weather)
	return ok(args[1])

func _crop(args: Array) -> Dictionary:
	if args.is_empty(): return fail("Use /help crop")
	var action: String = args[0]
	if action not in ["info", "grow", "water", "disease"]: return fail("Unknown crop action.")
	var offset: int = 2 if action == "disease" else 1
	if action == "disease" and (args.size() < 2 or args[1] not in ["pests", "weeds", "clear"]): return fail("Use disease pests|weeds|clear")
	var targets: Array[Vector2i] = []
	var tail: Array = args.slice(offset)
	if tail == ["all", "confirm"]:
		targets.assign(world.farming.crop_cells())
	elif tail.is_empty() or tail == ["here"]:
		targets.append(world.farming.world_to_cell(world.player.global_position))
	elif tail.size() == 2 and _integer(tail[0], -1000, 1000) and _integer(tail[1], -1000, 1000):
		targets.append(Vector2i(int(tail[0]), int(tail[1])))
	else: return fail("Target: here | x y | all confirm")
	var count: int = 0
	for cell: Vector2i in targets:
		var crop: Crop = world.farming.get_crop(cell)
		if action == "info": return ok({"cell": str(cell), "soil": world.farming.get_soil_state(cell), "crop": String(crop.definition.crop_id) if crop != null else "", "progress": crop.progress if crop != null else 0, "conditions": crop.conditions.capture() if crop != null else {}})
		if crop == null: continue
		if action == "grow":
			crop.restore_progress(crop.definition, minf(crop.planted_at, world.farming.time_manager.now() - 0.001), world.farming.time_manager.now(), 1.0, world.farming.time_manager.now(), crop.fertilized, crop.pollination_reduction, crop.watered, crop.root_boost, crop.conditions.capture())
			world.farming.reschedule_crop(crop)
		elif action == "water":
			if world.farming.apply_area(&"water", [cell], null, -1, null, world.player).changed == 0: continue
		else:
			crop.conditions.pest_checked = true
			crop.conditions.weed_checked = true
			if args[1] == "clear":
				crop.conditions.pests = false
				crop.conditions.weeds = false
			elif args[1] == "pests": crop.conditions.pests = true
			else: crop.conditions.weeds = true
			crop.refresh(world.farming.time_manager.now())
			crop.conditions_changed.emit()
		count += 1
	world.workers.bridge.invalidate_crops()
	world.workers.request_scan("crop")
	return ok({"changed": count})

func _land(args: Array) -> Dictionary:
	if args.size() != 1 or not _integer(args[0], world.land.state.unlocked_blocks, LandExpansionState.BLOCK_COUNT): return fail("Specify a block count at least the current count, up to 24.")
	world.land.state.restore_blocks(int(args[0]), world.land.state.starting_blocks)
	return ok(world.land.state.unlocked_blocks)

func _animals() -> Array[AnimalActor]:
	var result: Array[AnimalActor] = []
	for pen: AnimalPen in world.workers.bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalActor and not child.is_queued_for_deletion() and not (child as AnimalActor).is_dead(): result.append(child)
	return result

func _animal_target(id: String) -> AnimalActor:
	var nearest: AnimalActor
	var distance: float = 64.0
	for animal: AnimalActor in _animals():
		if String(animal.persistent_id) == id: return animal
		var next: float = animal.global_position.distance_to(world.player.global_position)
		if id == "here" and next < distance:
			nearest = animal
			distance = next
	return nearest

func _animal_info(animal: AnimalActor) -> Dictionary:
	return {"id": String(animal.persistent_id), "species": String(animal.definition.animal_id), "pen": String(animal.pen.persistent_id), "position": str(animal.global_position), "age": animal.growth.age_seconds, "health": animal.health.capture(), "food": animal.needs.satiety, "water": animal.needs.hydration, "stock": animal.production.stored_amount}

func _animal(args: Array) -> Dictionary:
	if args.is_empty(): return fail("Use /help animal")
	if args[0] == "list" and args.size() <= 2:
		var rows: Array = []
		for animal: AnimalActor in _animals():
			if args.size() == 1 or String(animal.definition.animal_id) == args[1]: rows.append(_animal_info(animal))
		return ok(rows)
	if args[0] == "spawn" and args.size() in [2, 3]:
		var definition: AnimalDefinition = resources().animals.get(args[1]) as AnimalDefinition
		var count: Variant = args[2] if args.size() == 3 else "1"
		if definition == null or not _integer(count, 1, 30): return fail("Invalid species/count.")
		var placement: AnimalTradeService = AnimalTradeService.new(null, world.player.wallet, world, world.farming.time_manager)
		for pen: AnimalPen in placement._pens():
			if not pen.accepted_species.has(definition.species): continue
			if pen is PondPen and not (pen as PondPen).navigation_ready: (pen as PondPen).rebuild_navigation()
			var points: Array[Vector2] = placement._spawn_positions(pen, definition, int(count))
			if points.size() != int(count): continue
			var scene: PackedScene = load(AnimalTradeService.ACTOR_PATH) as PackedScene
			for point: Vector2 in points:
				var actor: AnimalActor = scene.instantiate() as AnimalActor
				actor.definition = definition
				actor.pen = pen
				actor.position = point
				pen.add_child(actor)
			world.workers.bridge.invalidate_ranch()
			return ok({"spawned": int(count), "pen": String(pen.persistent_id)})
		return fail("No compatible pen has capacity and free spawn positions.")
	if args.size() < 2: return fail("Specify animal ID or here.")
	var target: AnimalActor = _animal_target(args[1])
	if target == null: return fail("Animal not found within this farm (here: 64 pixels).")
	if args[0] == "info" and args.size() == 2: return ok(_animal_info(target))
	target.needs.update_at(world.farming.time_manager.now())
	if args[0] == "disease" and args.size() == 3 and args[2] in ["on", "off"]:
		if args[2] == "off": target.cure_disease()
		else: target.health.sick = true
		target._refresh_health_badges()
	elif args[0] == "needs" and args.size() == 4 and args[2] in ["food", "water"] and _integer(args[3], 0, 100):
		target.needs.restore_state(float(args[3]) if args[2] == "food" else target.needs.satiety, float(args[3]) if args[2] == "water" else target.needs.hydration, world.farming.time_manager.now())
	elif args[0] == "age" and args.size() == 3 and args[2] in ["young", "adult"]:
		target.growth.configure(target.definition.maturity_seconds, target.definition.maturity_seconds if args[2] == "adult" else 0.0, target.definition.lifespan_seconds)
		target._apply_stage_visuals()
		target.behaviour.configure(target.definition)
	else: return fail("Invalid animal action or arguments. Use /help animal.")
	world.workers.bridge.invalidate_ranch()
	world.workers.request_scan("crop")
	return ok(_animal_info(target))

func _worker_row(id: String) -> Dictionary:
	for row: Dictionary in world.workers.records:
		if row.id == id or str(row.slot) == id: return row
	return {}

func _worker(args: Array) -> Dictionary:
	var team: WorkerService = world.workers
	if args == ["list"]: return ok(team.records)
	if args == ["hire"]:
		var error: String = team.hire("crop")
		return ok("Worker hired.") if error.is_empty() else fail(error)
	if args.size() == 4 and args[0] == "upgrade": return fail("Use /worker upgrade track level")
	if args.size() == 3 and args[0] == "upgrade":
		var track: String = args[1]
		if track not in WorkerUpgradeState.TRACKS or not _integer(args[2], 0 if track == "speed" else 1, WorkerUpgradeState.maximum(track)): return fail("Invalid track/level. Speed 0-10; tools 1-3.")
		team.settle(world.farming.time_manager.now())
		team.upgrades.levels[track] = int(args[2])
		team.changed.emit()
		return ok(team.upgrades.levels)
	if args.size() != 2: return fail("Use /help worker")
	var row: Dictionary = _worker_row(args[1])
	if args[0] in ["info", "target"]:
		if row.is_empty(): return fail("Worker not found.")
		return ok(row if args[0] == "info" else {"task": row.task, "reserved": str(team.reservations()), "waiting": team.waiting_reasons.get(row.id, ""), "navigation_pending": team.navigation.jobs.size()})
	if args[0] not in ["pause", "resume"]: return fail("Unknown worker action.")
	var selected: Array = team.records if args[1] == "all" else [row] if not row.is_empty() else []
	if selected.is_empty(): return fail("No workers selected.")
	if args[0] == "resume":
		for entry: Dictionary in selected:
			if entry.employed and entry.paid_through_day < entry.last_wage_day: return fail("An unpaid worker cannot resume yet.")
		if team.crop_automation.paused:
			if args[1] != "all": return fail("Team is paused globally. Use /worker resume all.")
			team.configure_crop(team.crop_automation.auto_plant, team.crop_automation.auto_fertilize, false)
	for entry: Dictionary in selected:
		if not entry.employed: continue
		if bool(entry.active) != (args[0] == "resume"):
			var error: String = team.set_active(entry.id, args[0] == "resume")
			if not error.is_empty(): return fail(error)
	return ok("Worker state updated.")

func _upgrade(args: Array) -> Dictionary:
	if args.size() != 3: return fail("Usage: /upgrade tool|pen id level")
	if args[0] == "tool":
		var data: Dictionary = world.tool_upgrade_state.capture()
		if not data.has(args[1]) or not _integer(args[2], 1, ToolUpgradeState.MAX_LEVEL): return fail("Unknown tool or level 1-6 required.")
		data[args[1]] = {"level": int(args[2]), "selected_size": int(args[2])}
		return ok(world.tool_upgrade_state.restore(data))
	if args[0] == "pen":
		var data: Dictionary = world.pen_upgrades.state.capture()
		if not data.has(args[1]) or not _integer(args[2], 1, PenUpgradeState.MAX_LEVEL): return fail("Unknown pen or level 1-6 required.")
		for pen: AnimalPen in world.workers.bridge.pens():
			if String(pen.persistent_id) == args[1]:
				var population: int = 0
				for child: Node in pen.get_children():
					if child is AnimalActor and not (child as AnimalActor).is_dead(): population += 1
				if population > int(args[2]) * 5: return fail("Level cannot hold existing animals.")
		data[args[1]] = int(args[2])
		if not world.pen_upgrades.state.restore(data): return fail("Pen upgrade state rejected.")
		world.pen_upgrades.apply_capacities()
		world.pen_upgrades.state.changed.emit(StringName(args[1]))
		return ok(data)
	return fail("Unknown upgrade kind.")

func _objective(args: Array) -> Dictionary:
	var model: ObjectiveProgress = world.objectives.progress
	if args == ["list"]: return ok(model.capture())
	if args.size() != 2 or args[0] != "complete" or model.active() == null or String(model.active().objective_id) != args[1]: return fail("Specify the current active objective ID.")
	var data: Dictionary = model.capture()
	data.steps[model.active_index()].progress = model.active().required
	return ok(model.restore(data))

func _orders(args: Array) -> Dictionary:
	return ok(world.orders.service.capture()) if args.is_empty() else fail("Usage: /order list")

func _save(args: Array) -> Dictionary:
	if args == ["status"]: return ok({"profile": SaveManager.profile_id, "revision": SaveManager.revision, "busy": SaveManager.busy, "writes_enabled": SaveManager.writes_enabled, "bound_to_this_world": SaveManager.adapter != null and SaveManager.adapter.world == world})
	if args != ["validate"]: return fail("Usage: /save status|validate")
	var snapshot: Dictionary = WorldStateAdapter.new(world, resources()).capture("debug", 1, world.farming.time_manager.now())
	var checked: Dictionary = SaveSchema.validate(snapshot, resources())
	var report: Dictionary = {"live_ok": checked.ok, "live_error": checked.get("error", "")}
	if SaveManager.adapter != null and SaveManager.adapter.world == world and SaveManager.repository is LocalSaveRepository:
		var repository: LocalSaveRepository = SaveManager.repository as LocalSaveRepository
		for suffix: String in ["", ".bak"]:
			var read: Dictionary = repository._read(repository.path(SaveManager.profile_id) + suffix, SaveManager.profile_id)
			report["primary" if suffix.is_empty() else "backup"] = {"ok": read.ok, "error": read.get("error", "")}
	return ok(report)

func _perf(args: Array) -> Dictionary:
	if args.size() != 1 or args[0] not in ["on", "off", "snapshot"]: return fail("Usage: /perf on|off|snapshot")
	if args[0] != "snapshot":
		world.workers.profiling = args[0] == "on"
		world.workers.navigation.profiling = args[0] == "on"
		perf_changed.emit(args[0] == "on")
	return ok({"fps": Engine.get_frames_per_second(), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "workers": world.workers.actors.size(), "scheduler_ms_total": world.workers.scheduler_usec / 1000.0, "commit_ms_total": world.workers.commit_usec / 1000.0, "navigation_ms_total": world.workers.navigation.profile_usec / 1000.0})

func suggestions(line: String) -> Array[String]:
	var result: Array[String] = []
	var prefix: String = line.trim_prefix("/").to_lower()
	for path: String in registry.commands:
		if path.begins_with(prefix): result.append("/" + path)
	if result.is_empty():
		var split: int = line.rfind(" ")
		var tail: String = line.substr(split + 1)
		var base: String = line.substr(1, maxi(0, split - 1))
		var choices: Dictionary = {
			"find": ["item", "crop", "animal"], "money": ["get", "set", "add"],
			"storage": ["info", "add"], "storage add": ["supply", "produce"], "storage info": ["supply", "produce"],
			"time": ["get", "hour", "advance"], "weather": ["set", "auto"], "weather set": ["sunny", "rain", "cloudy", "windy"],
			"crop": ["info", "grow", "water", "disease"], "crop disease": ["pests", "weeds", "clear"],
			"animal": ["list", "info", "spawn", "disease", "needs", "age"],
			"worker": ["list", "info", "target", "hire", "pause", "resume", "upgrade"], "worker upgrade": WorkerUpgradeState.TRACKS,
			"upgrade": ["tool", "pen"], "upgrade tool": ToolUpgradeState.TOOLS, "upgrade pen": world.pen_upgrades.state.capture().keys(),
			"objective": ["list", "complete"], "save": ["status", "validate"], "perf": ["on", "off", "snapshot"],
			"tp": ["workers", "farm", "coop", "barn", "pond", "orders"]}
		var ids: Array = choices.get(base, [])
		if base == "give" or base.begins_with("storage add ") and base.split(" ").size() == 3 or base == "find item": ids = resources().items.keys()
		elif base in ["animal spawn", "animal list", "find animal"]: ids = resources().animals.keys()
		elif base == "find crop": ids = resources().crops.keys()
		elif base in ["worker info", "worker target", "worker pause", "worker resume"]:
			ids = ["all"] if base in ["worker pause", "worker resume"] else []
			for row: Dictionary in world.workers.records:
				ids.append(str(row.slot))
				ids.append(String(row.id))
		elif base in ["animal info", "animal disease", "animal needs", "animal age"]:
			ids = ["here"]
			for animal: AnimalActor in _animals(): ids.append(String(animal.persistent_id))
		elif base == "objective complete":
			ids = []
			if world.objectives.progress.active() != null: ids.append(String(world.objectives.progress.active().objective_id))
		for id: String in ids:
			var candidate: String = line.substr(0, split + 1) + id
			if id.begins_with(tail) and not result.has(candidate): result.append(candidate)
	result.sort()
	return result.slice(0, 30)
