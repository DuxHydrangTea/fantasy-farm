extends Node
## Same seeded world, real rendered frames. Legacy 15 actors are fixture-only:
## production hire/restore validation continue to cap the roster at three.
var world: FarmWorld
var results: Array[Dictionary] = []
var profile_snapshot: Dictionary = {}
var save_hashes: Dictionary = {}
var save_checks: Dictionary = {}
var actions: Dictionary = {}
var harvested_value: int = 0
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const FIXED: float = 1793155000.0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("profile"):
		var repository: LocalSaveRepository = LocalSaveRepository.new()
		for suffix: String in ["", ".bak"]:
			var path: String = repository.path("local") + suffix
			save_hashes[path] = FileAccess.get_file_as_string(path).sha256_text()
			var check: Dictionary = repository._read(path, "local")
			save_checks["primary" if suffix.is_empty() else "backup"] = {"ok": check.ok, "revision": check.get("revision", -1)}
			assert(check.ok, "Primary and backup must both validate before profiling")
		var checked: Dictionary = repository.read_profile("local")
		assert(checked.ok and checked.get("found", false), "Local profile must be valid")
		profile_snapshot = checked.snapshot
	for run: int in range(2):
		var configs: Array = [[15, 0, 1], [3, 0, 1], [3, 5, 2], [3, 10, 3]] if profile_snapshot.is_empty() else [[15, 0, 1], [3, 10, 3]]
		if run == 1:
			configs.reverse()
		for config: Array in configs:
			await _scenario(run, int(config[0]), int(config[1]), int(config[2]))
	var save_unchanged: bool = true
	for path: String in save_hashes:
		save_unchanged = save_unchanged and FileAccess.get_file_as_string(path).sha256_text() == save_hashes[path]
	assert(save_unchanged and SaveManager.adapter == null, "Benchmark may never modify the playing profile")
	var output: String = args[0] if not args.is_empty() else "C:/projects/fantasy-farm/.godot/worker-upgrades-benchmark.json"
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "save_bound": SaveManager.adapter != null, "save_unchanged": save_unchanged, "profile_copy": not profile_snapshot.is_empty(), "save_checks": save_checks, "scenarios": results}, "\t"))
	file.close()
	get_tree().quit()

func _scenario(run: int, count: int, speed: int, width: int) -> void:
	seed(12345)
	var baseline: float = float(profile_snapshot.get("saved_at", FIXED))
	TimeManager._last_timestamp = baseline
	TimeManager.clock_source = func() -> float: return baseline
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	world.tool_upgrades.profile_ready = true
	if profile_snapshot.is_empty():
		world.land.state.restore_blocks(16, 4)
		world.trees.reset()
		world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
		world.farming.restore_soil([])
	else:
		var saved: Dictionary = profile_snapshot.duplicate(true)
		saved.workers.rows = []
		saved.workers.legacy_baskets = []
		saved.workers.crop_automation.prepared = []
		saved.workers.crop_automation.paused = false
		var restored: Dictionary = WorldStateAdapter.new(world, SaveCatalog.new()).restore(saved, baseline)
		assert(restored.ok, str(restored))
	world.player.wallet.set_balance(10000000)
	world.workers.feed_inventory("crop").add(SEED, 1000)
	world.workers.upgrades.levels = {"speed": speed, "hoe": width, "sowing": width, "watering": width, "harvest": width}
	world.farming.crop_planted.connect(func(_cell: Vector2i, crop: Crop) -> void:
		crop.conditions.pest_roll = 1.0
		crop.conditions.weed_roll = 1.0
		crop.conditions.yield_roll = 0.5)
	if profile_snapshot.is_empty():
		# Identical mature and thirsty crops make every measured window exercise
		# harvesting, care and replanting, rather than only the first soil pass.
		var soil: Array = []
		for cell: Vector2i in WorkerAreaPolicy.footprint(Vector2i(54, 30), 3) + WorkerAreaPolicy.footprint(Vector2i(54, 34), 3):
			soil.append({"cell": [cell.x, cell.y], "state": 1})
		world.farming.restore_soil(soil)
		for entry: Dictionary in soil:
			var cell: Vector2i = Vector2i(entry.cell[0], entry.cell[1])
			world.farming.restore_crop(cell, SEED.crop, baseline - 100, baseline - 1 if cell.y < 32 else baseline + 60, 1.0 if cell.y < 32 else 0.0, baseline)
			var crop: Crop = world.farming.get_crop(cell)
			crop.conditions.pests = false
			crop.conditions.weeds = false
			crop.conditions.yield_roll = 0.5
	for pen: AnimalPen in (world.workers.bridge.pens() if profile_snapshot.is_empty() else []):
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				(child as AnimalTrough).stock = (child as AnimalTrough).capacity
	world.workers.hire("crop")
	var template: Dictionary = world.workers.records[0].duplicate(true)
	for index: int in range(1, count):
		if index < 3:
			world.workers.hire("crop")
		else:
			var row: Dictionary = template.duplicate(true)
			row.id = "benchmark_legacy_%d" % index
			row.slot = index + 1
			row.hire_order = index + 1
			row.position = WorkerRole.pair(world.workers.spawn_point("crop", ""))
			world.workers.records.append(row)
			world.workers._spawn(row)
	world.workers.next_order = count + 1
	# Employment uses random persistent IDs in production. Normalize fixture IDs
	# so patrol/rest hashes and the first three actors match across all scenarios.
	for index: int in range(world.workers.records.size()):
		var row: Dictionary = world.workers.records[index]
		var actor: WorkerActor = world.workers.actor_for(row.id)
		world.workers.actors.erase(row.id)
		row.id = "benchmark_%02d" % index
		actor.persistent_id = StringName(row.id)
		world.workers.actors[row.id] = actor
		row.task = {}
		row.wake_at = baseline
	world.workers.crop_automation.prepared.clear()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	var started: int = Time.get_ticks_usec()
	TimeManager.clock_source = func() -> float: return baseline + float(Time.get_ticks_usec() - started) / 1000000.0
	var warm_frames: int = 0
	while warm_frames < 120 or Time.get_ticks_usec() - started < 3000000:
		await get_tree().process_frame
		warm_frames += 1
	actions = {}
	harvested_value = 0
	var prices: ProducePriceCatalog = preload("res://resources/shops/produce_prices.tres")
	world.farming.quality_harvest_yielded.connect(func(item: ItemDefinition, amount: int, _at: Vector2, _inventory: InventoryComponent, tier: int) -> void:
		var price: ProducePrice = prices.find(item.item_id)
		if price != null:
			harvested_value += amount * ItemQuality.unit_price(price.price, tier))
	world.farming.action_committed.connect(func(kind: StringName, amount: int) -> void:
		actions[String(kind)] = int(actions.get(String(kind), 0)) + amount)
	var team: WorkerService = world.workers
	team.profiling = true
	team.navigation.profiling = true
	var activity: Dictionary = {"travel": 0.0, "care": 0.0, "field": 0.0, "idle": 0.0}
	var processing: Array[float] = []
	var physics: Array[float] = []
	var seed_before: int = team.feed_inventory("crop").count_item(SEED.item_id)
	var supplies_before: Dictionary = _supplies(team)
	var wallet_before: int = world.player.wallet.balance
	var frames: Array[float] = []
	var begin: int = Time.get_ticks_usec()
	var previous: int = begin
	var sample_usec: int = 20000000 if profile_snapshot.is_empty() else 60000000
	while Time.get_ticks_usec() - begin < sample_usec:
		await get_tree().process_frame
		var current: int = Time.get_ticks_usec()
		frames.append(float(current - previous) / 1000.0)
		processing.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var delta: float = float(current - previous) / 1000000.0
		for row: Dictionary in team.records:
			var kind: String = String(row.task.get("kind", "patrol"))
			var actor: WorkerActor = team.actor_for(row.id)
			var state: String = "idle"
			if not row.task.is_empty() and kind != "patrol":
				state = "travel" if actor.global_position.distance_to(WorkerRole.point(row.task.point)) > 3.0 else "care" if kind in ["fertilize", "water_crop", "treat_pests", "treat_weeds", "cure_animal", "feed", "water_trough", "fetch_water"] else "field"
			activity[state] += delta
		previous = current
	var elapsed: float = float(Time.get_ticks_usec() - begin) / 1000000.0
	var completed: int = 0
	var field_actions: Dictionary = {}
	for kind: String in ["till", "plant", "water_crop", "harvest"]:
		field_actions[kind] = int(actions.get(kind, 0))
		completed += int(field_actions[kind])
	for state: String in activity:
		activity[state] /= elapsed * count
	var animal_count: int = 0
	for pen: AnimalPen in team.bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalActor:
				animal_count += 1
	var result: Dictionary = {"run": run, "workers": count, "speed_level": speed, "width": width, "seconds": elapsed, "fps": frames.size() / elapsed, "frames": _stats(frames), "process": _stats(processing), "physics": _stats(physics), "actions": actions.duplicate(), "field_actions": field_actions, "cell_actions_per_minute": completed * 60.0 / elapsed, "actors": team.actors.size(), "activity_share": activity, "seed_spent": seed_before - team.feed_inventory("crop").count_item(SEED.item_id), "wages_paid": wallet_before - world.player.wallet.balance, "scheduler_ms": team.scheduler_usec / 1000.0, "commit_ms": team.commit_usec / 1000.0, "commit_max_ms": team.commit_max_usec / 1000.0, "navigation_ms": team.navigation.profile_usec / 1000.0, "navigation_max_ms": team.navigation.profile_max_usec / 1000.0, "crops": world.farming.crop_cells().size(), "animals": animal_count}
	var supply_cost: int = 0
	var stock: ShopCatalog = preload("res://resources/shops/farm_supply.tres")
	var supplies_after: Dictionary = _supplies(team)
	for offer: ShopOffer in stock.offers:
		var id: String = String(offer.item.item_id)
		supply_cost += maxi(0, int(supplies_before.get(id, 0)) - int(supplies_after.get(id, 0))) * offer.price
	var accrued_wages: float = count * int(WorkerRole.WAGES.crop) * elapsed / 86400.0
	result["economy"] = {"harvested_field_value": harvested_value, "supply_replacement_cost": supply_cost, "accrued_wages": accrued_wages, "field_margin": harvested_value - supply_cost - accrued_wages, "realized_sales": 0, "note": "Short-window field output valuation; excludes orchard/animal output, sales and upgrade payback."}
	results.append(result)
	print("WORKER_UPGRADE_BENCHMARK ", JSON.stringify(result))
	world.free()
	await get_tree().process_frame

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p95_ms": values[ceili(values.size() * 0.95) - 1], "p99_ms": values[ceili(values.size() * 0.99) - 1], "max_ms": values.back()}

func _supplies(team: WorkerService) -> Dictionary:
	var result: Dictionary = {}
	var bag: InventoryComponent = team.feed_inventory("crop")
	for index: int in range(bag.slot_count):
		var slot: Dictionary = bag.slot(index)
		if slot.item != null:
			var id: String = String(slot.item.item_id)
			result[id] = int(result.get(id, 0)) + int(slot.count)
	return result
