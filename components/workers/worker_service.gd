class_name WorkerService
extends Node
## One ordered event timeline for all roles. No background per-tile nodes.
signal changed
const SCENES: Dictionary = {"orchard": preload("res://scenes/workers/orchard_worker.tscn"), "ranch": preload("res://scenes/workers/ranch_worker.tscn"), "crop": preload("res://scenes/workers/crop_worker.tscn")}
const DEFINITIONS: Dictionary = {"orchard": preload("res://resources/workers/orchard_hand.tres"), "ranch": preload("res://resources/workers/ranch_hand.tres"), "crop": preload("res://resources/workers/crop_hand.tres")}
var world: FarmWorld
var bridge: WorkerWorldBridge
var records: Array[Dictionary] = []
var actors: Dictionary = {}
var trial_used: Array[String] = []
var next_order: int = 1
var simulated_at: float = 0.0
var busy: bool = false
var blocked_targets: Dictionary = {}
var trough_levels: Dictionary = {}
var legacy_pending: bool = false
var crop_automation: CropAutomationState = CropAutomationState.new()
var crop_policy: CropWorkerPolicy

func _ready() -> void:
	bridge = WorkerWorldBridge.new(world)
	crop_policy = CropWorkerPolicy.new(world)
	world.storages.changed.connect(_warehouse_changed)
	simulated_at = world.farming.time_manager.now()
	world.farming.time_manager.before_tick.connect(_before_tick)
	world.farming.crop_planted.connect(_crop_planted)
	world.farming.crop_harvested.connect(_crop_harvested)
	world.farming.soil_changed.connect(_soil_changed)
	world.land.state.changed.connect(func() -> void:
		crop_policy.invalidate()
		request_scan("crop"))
	get_tree().node_added.connect(_node_added)
	for pen: AnimalPen in bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				trough_levels[child.get_instance_id()] = int(child.stock)
				child.stock_changed.connect(_trough_changed.bind(child))

		var source: Node2D = Node2D.new()
		source.name = "WorkerWaterSource"
		pen.add_child(source)
		source.global_position = bridge.home("ranch", String(pen.persistent_id))
		var label: Label = Label.new()
		label.text = tr("Water source")
		label.position = Vector2(-18, -8)
		label.scale = Vector2(0.3, 0.3)
		label.modulate = Color(0.6, 0.85, 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source.add_child(label)

func record(role: String) -> Dictionary:
	for row: Dictionary in records:
		if row.role == role:
			return row
	return {}

func bag_for(role: String) -> InventoryComponent:
	var actor: WorkerActor = actors.get(role) as WorkerActor
	return actor.basket if is_instance_valid(actor) else null

func output_inventory() -> InventoryComponent:
	return world.storages.inventory("produce_warehouse")

func feed_inventory(role: String) -> InventoryComponent:
	return world.storages.inventory("farm_supply_storage") if role == "ranch" else bag_for(role)

func _warehouse_changed(id: String) -> void:
	if not busy:
		legacy_pending = true
	for row: Dictionary in records:
		if id != "farm_supply_storage" or row.role in ["ranch", "crop"]:
			request_scan(row.role)

func _drain_legacy_products() -> void:
	legacy_pending = false
	for row: Dictionary in records:
		world.storages.import_worker_products(bag_for(row.role))
		world.storages.import_worker_products(bag_for(row.role), true)

func available() -> bool:
	return world.tool_upgrades != null and world.tool_upgrades.profile_ready and not world.storages.busy

func unlock_error(role: String) -> String:
	if role == "orchard":
		var count: int = 0
		for tree: PerennialTree in world.trees.trees.values():
			if tree is FruitTree and not tree.removed:
				count += 1
		return "Plant at least 10 fruit trees." if count < 10 else ""
	if role == "ranch":
		return "At least 2 animal pens are required." if bridge.pens().size() < 2 else ""
	return "Unlock at least 12 farmland columns." if world.land.state.unlocked_columns < 12 else ""

func hire(role: String, zone: String = "") -> String:
	if busy or not available() or not role in WorkerRole.ROLES:
		return "Workers are unavailable."
	settle(world.farming.time_manager.now())
	var error: String = unlock_error(role)
	if not error.is_empty():
		return error
	var row: Dictionary = record(role)
	if not row.is_empty() and row.employed:
		return "This role is already hired."
	if role == "ranch" and bridge.pen_for(zone) == null:
		return "Choose an animal pen."
	var wage: int = int(WorkerRole.WAGES[role]) if role in trial_used else 0
	if world.player.wallet.balance < wage:
		return "Not enough coins for today's wage."
	busy = true
	var now: float = simulated_at
	var day: int = world.weather.schedule.day_at(now)
	if row.is_empty():
		if role == "crop":
			crop_automation.auto_plant = true
			crop_automation.revision += 1
		row = {"id": "worker_" + Crypto.new().generate_random_bytes(12).hex_encode(), "role": role, "zone": zone, "employed": true, "active": true, "hire_order": next_order, "paid_through_day": day, "last_wage_day": day, "position": WorkerRole.pair(bridge.home(role, zone)), "task": {}, "wake_at": now, "water_units": 0, "paused_at": 0.0, "patrol_index": 0}
		records.append(row)
		_spawn(row)
	else:
		row.employed = true
		row.active = true
		row.zone = zone
		row.hire_order = next_order
		row.paid_through_day = day
		row.last_wage_day = day
		row.wake_at = now
		row.paused_at = 0.0
		row.position = WorkerRole.pair(bridge.home(role, zone))
		(actors[role] as WorkerActor).global_position = WorkerRole.point(row.position)
	next_order += 1
	if not role in trial_used:
		trial_used.append(role)
	world.player.wallet.set_balance(world.player.wallet.balance - wage)
	changed.emit()
	busy = false
	return ""

func dismiss(role: String) -> String:
	if busy or not available():
		return "Workers are unavailable."
	settle(world.farming.time_manager.now())
	var row: Dictionary = record(role)
	if row.is_empty():
		return "No worker hired."
	busy = true
	row.employed = false
	row.active = false
	row.task = {}
	# Keep the basket and trial flag. Rehiring never reissues a free shift.
	changed.emit()
	busy = false
	return ""

func transfer(role: String, customer: InventoryComponent, deposit: bool, supplies: bool) -> int:
	if busy or not available() or (deposit and supplies):
		return 0
	settle(world.farming.time_manager.now())
	var bag: InventoryComponent = bag_for(role)
	if bag == null or customer == null:
		return 0
	busy = true
	var source: InventoryComponent = customer if deposit else bag
	var target: InventoryComponent = bag if deposit else customer
	var total: int = 0
	for index: int in range(source.slot_count):
		var stack: Dictionary = source.slot(index)
		var item: ItemDefinition = stack.item as ItemDefinition
		if item == null or (item.item_type == ItemDefinition.ItemType.FEED) != supplies:
			continue
		if not supplies and item.item_type != ItemDefinition.ItemType.PRODUCE:
			continue
		var amount: int = mini(int(stack.count), target.capacity_for(item))
		if amount <= 0:
			continue
		var accepted: int = source.transfer_slot_to(index, target, amount, false)
		total += accepted
	source.changed.emit()
	target.changed.emit()
	var row: Dictionary = record(role)
	row.wake_at = simulated_at
	changed.emit()
	busy = false
	return total

func _spawn(row: Dictionary) -> void:
	var actor: WorkerActor = (SCENES[row.role] as PackedScene).instantiate() as WorkerActor
	actor.persistent_id = StringName(row.id)
	actor.worker_service = self
	actor.worker_role = row.role
	world.add_child(actor)
	actor.global_position = WorkerRole.point(row.position)
	actors[row.role] = actor
	var access: WorkerBoard = (load("res://scenes/workers/worker_board.tscn") as PackedScene).instantiate() as WorkerBoard
	access.role = row.role
	access.worker_access = true
	actor.add_child(access)

func _pay(row: Dictionary, day: int) -> void:
	if not row.employed or int(row.last_wage_day) >= day:
		return
	var wage: int = int(WorkerRole.WAGES[row.role])
	var previously_active: bool = bool(row.active)
	row.active = world.player.wallet.balance >= wage
	row.last_wage_day = day
	if row.active:
		row.paid_through_day = day
		if row.role != "crop" or not crop_automation.paused:
			_resume_task(row, simulated_at)
		world.player.wallet.set_balance(world.player.wallet.balance - wage)
	elif previously_active and float(row.paused_at) == 0.0:
		row.paused_at = simulated_at
	row.wake_at = simulated_at

func blocked(role: String, now: float) -> void:
	var row: Dictionary = record(role)
	if row.is_empty() or busy:
		return
	row.position = WorkerRole.pair((actors[role] as WorkerActor).global_position)
	var task: Dictionary = row.task
	if task.is_empty():
		return
	var attempt: int = int(task.get("attempt", 0)) + 1
	if attempt <= 4:
		var offsets: Array[Vector2] = [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]
		var point: Vector2 = WorkerRole.point(task.base_point) + offsets[attempt - 1]
		if bridge.zone_contains(row, point):
			task.point = WorkerRole.pair(point)
			task.attempt = attempt
			task.finish_at = now + WorkerRole.point(row.position).distance_to(point) / (actors[role] as WorkerActor).movement.speed + (actors[role] as WorkerActor).definition.work_seconds
			task.work_at = task.finish_at - (actors[role] as WorkerActor).definition.work_seconds
			return
	blocked_targets[role + ":" + String(task.id)] = now + 120.0
	if role == "crop" and task.kind == "plant":
		crop_automation.prepared = Vector2i(-1, -1)
	row.task = {}
	row.wake_at = now

func _before_tick(timestamp: float) -> void:
	if not available() or records.is_empty() or timestamp - simulated_at < 0.25:
		return
	# Catch up workers before other world systems consume this same time span.
	advance(timestamp, timestamp - simulated_at > 5.0)

func settle(now: float) -> void:
	advance(now, now - simulated_at > 5.0)

func advance(until: float, offline: bool = true) -> void:
	if busy or world.storages.busy or not is_finite(until) or until < simulated_at:
		return
	if records.is_empty():
		simulated_at = until
		return
	busy = true
	var clock: FarmClock = world.farming.time_manager
	var previous: float = clock.simulation_timestamp
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hire_order) < int(b.hire_order))
	while simulated_at <= until:
		clock.simulation_timestamp = simulated_at
		if legacy_pending:
			_drain_legacy_products()
		bridge.sync(simulated_at, offline)
		var day: int = world.weather.schedule.day_at(simulated_at)
		for row: Dictionary in records:
			_pay(row, day)
			if not running(row):
				continue
			var actor: WorkerActor = actors[row.role] as WorkerActor
			var task: Dictionary = row.task
			if not task.is_empty() and float(task.finish_at) <= simulated_at + 0.00001:
				var target: Vector2 = WorkerRole.point(task.point)
				if not offline and actor.global_position.distance_to(target) > 3.0:
					task.finish_at = simulated_at + 0.25
				else:
					row.position = task.point.duplicate()
					if offline:
						actor.global_position = target
					bridge.commit(row, feed_inventory(row.role), task)
					row.task = {}
					row.wake_at = simulated_at
			if row.task.is_empty() and float(row.wake_at) <= simulated_at:
				if not offline:
					row.position = WorkerRole.pair(actor.global_position)
				var options: Array[Dictionary] = []
				for option: Dictionary in bridge.candidates(row, feed_inventory(row.role)):
					if float(blocked_targets.get(String(row.role) + ":" + String(option.id), 0)) <= simulated_at and bridge.zone_contains(row, WorkerRole.point(option.point)):
						options.append(option)
				var chosen: Dictionary = WorkerRole.choose(options, WorkerRole.point(row.position))
				var wake: float = bridge.next_wake(row, feed_inventory(row.role), simulated_at)
				if chosen.is_empty():
					chosen = {"kind": "patrol", "id": "patrol", "point": WorkerRole.pair(bridge.patrol_point(row)), "priority": 9}
				if not chosen.is_empty() and bridge.zone_contains(row, WorkerRole.point(chosen.point)):
					chosen["base_point"] = chosen.point.duplicate()
					chosen["attempt"] = 0
					chosen["work_at"] = simulated_at + WorkerRole.point(row.position).distance_to(WorkerRole.point(chosen.point)) / actor.movement.speed + actor.movement.speed / actor.movement.acceleration
					chosen["finish_at"] = chosen.work_at + actor.definition.work_seconds
					if chosen.kind == "patrol":
						chosen.finish_at = maxf(float(chosen.finish_at), minf(simulated_at + 60.0, wake))
					row.task = chosen
				else:
					row.wake_at = bridge.next_wake(row, feed_inventory(row.role), simulated_at)
		if simulated_at >= until:
			break
		var next: float = minf(until, world.weather.schedule.dawn_at(day + 1))
		for row: Dictionary in records:
			if running(row):
				next = minf(next, float(row.task.finish_at) if not row.task.is_empty() else float(row.wake_at))
		simulated_at = minf(until, maxf(simulated_at + 0.00001, next))
	clock.simulation_timestamp = previous
	busy = false

func capture(now: float) -> Dictionary:
	settle(now)
	var rows: Array = []
	for row: Dictionary in records:
		var copy: Dictionary = row.duplicate(true)
		copy["position"] = WorkerRole.pair((actors[row.role] as WorkerActor).global_position)
		if not copy.task.is_empty() and running(row):
			var remaining: float = WorkerRole.point(copy.position).distance_to(WorkerRole.point(copy.task.point))
			if remaining > 3.0:
				copy.task.work_at = maxf(float(copy.task.work_at), now + remaining / (actors[row.role] as WorkerActor).movement.speed)
				copy.task.finish_at = maxf(float(copy.task.finish_at), float(copy.task.work_at) + (actors[row.role] as WorkerActor).definition.work_seconds)
		copy["basket"] = []
		var bag: InventoryComponent = bag_for(row.role)
		for i: int in range(bag.slot_count):
			var stack: Dictionary = bag.slot(i)
			copy.basket.append({"item": String(stack.item.item_id) if stack.item != null else "", "count": int(stack.count), "tiers": stack.tiers.duplicate()})
		rows.append(copy)
	return {"rows": rows, "trial_used": trial_used.duplicate(), "next_order": next_order, "simulated_at": simulated_at, "crop_automation": crop_automation.capture()}

func restore(data: Dictionary, catalog: SaveCatalog) -> void:
	busy = true
	for actor: WorkerActor in actors.values():
		actor.free()
	actors.clear()
	blocked_targets.clear()
	bridge.storage_waiting.clear()
	records.clear()
	trial_used.assign(data.trial_used)
	next_order = int(data.next_order)
	simulated_at = float(data.simulated_at)
	crop_automation.restore(data.crop_automation)
	crop_policy.invalidate()
	for saved: Dictionary in data.rows:
		var row: Dictionary = saved.duplicate(true)
		row.erase("basket")
		records.append(row)
		_spawn(row)
		var stacks: Array[Dictionary] = []
		for slot: Dictionary in saved.basket:
			stacks.append({"item": catalog.items.get(slot.item), "count": int(slot.count), "tiers": slot.tiers.duplicate()})
		bag_for(row.role).replace_slots(stacks)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hire_order) < int(b.hire_order))
	_drain_legacy_products()
	busy = false

func request_scan(role: String) -> void:
	var row: Dictionary = record(role)
	if not row.is_empty():
		row.wake_at = minf(float(row.wake_at), world.farming.time_manager.now())
		if not row.task.is_empty() and row.task.kind == "patrol":
			row.task = {}

func _node_added(node: Node) -> void:
	if not world.is_ancestor_of(node):
		return
	if node is PerennialTree:
		request_scan("orchard")
	elif node is ItemPickup:
		_pickup_added.call_deferred(node)

func _pickup_added(node: Node) -> void:
	if not is_instance_valid(node) or not node is ItemPickup or not world.is_ancestor_of(node):
		return
	for row: Dictionary in records:
		if bridge.zone_contains(row, (node as ItemPickup).global_position):
			request_scan(row.role)

func _trough_changed(stock: int, trough: AnimalTrough) -> void:
	var key: int = trough.get_instance_id()
	if int(trough_levels.get(key, stock)) != stock:
		trough_levels[key] = stock
		request_scan("ranch")

func running(row: Dictionary) -> bool:
	return bool(row.employed) and bool(row.active) and not (row.role == "crop" and crop_automation.paused)

func _resume_task(row: Dictionary, timestamp: float) -> void:
	if float(row.paused_at) > 0 and not row.task.is_empty():
		var gap: float = maxf(0, timestamp - float(row.paused_at))
		row.task.work_at += gap
		row.task.finish_at += gap
	row.paused_at = 0.0

func configure_crop(plant: bool, fertilizer: bool, pause: bool) -> String:
	if busy or not available() or record("crop").is_empty():
		return "Workers are unavailable."
	settle(world.farming.time_manager.now())
	busy = true
	var row: Dictionary = record("crop")
	var changed_options: bool = plant != crop_automation.auto_plant or fertilizer != crop_automation.auto_fertilize
	if changed_options:
		crop_automation.revision += 1
		if not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"]:
			row.task = {}
	crop_automation.auto_plant = plant
	crop_automation.auto_fertilize = fertilizer
	if pause and not crop_automation.paused and float(row.paused_at) == 0.0:
		row.paused_at = simulated_at
	elif not pause and crop_automation.paused and row.active:
		_resume_task(row, simulated_at)
	crop_automation.paused = pause
	row.wake_at = simulated_at
	request_scan("crop")
	changed.emit()
	busy = false
	return ""

func _soil_changed(cell: Vector2i, _old: int, current: int) -> void:
	crop_policy.soil_changed(cell, current)
	request_scan("crop")

func _crop_planted(cell: Vector2i, _crop: Crop) -> void:
	crop_automation.forget_crop(cell)
	request_scan("crop")

func _crop_harvested(cell: Vector2i) -> void:
	crop_automation.forget_crop(cell)
	request_scan("crop")
