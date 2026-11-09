class_name WorkerService
extends Node
## One ordered event timeline for all roles. No background per-tile nodes.
signal wage_paid
signal changed
signal catch_up_progress(fraction: float)
const SCENES: Dictionary = {"crop": preload("res://scenes/workers/crop_worker.tscn")}
const DEFINITIONS: Dictionary = {"crop": preload("res://resources/workers/crop_hand.tres")}
var world: FarmWorld
var bridge: WorkerWorldBridge
var records: Array[Dictionary] = []
var actors: Dictionary = {}
var trial_used: Array[String] = []
var next_order: int = 1
var simulated_at: float = 0.0
var busy: bool = false
var blocked_targets: Dictionary = {}
var waiting_reasons: Dictionary[String, String] = {}
var trough_levels: Dictionary = {}
var legacy_pending: bool = false
var crop_automation: CropAutomationState = CropAutomationState.new()
var _pending_pickups: Array[WeakRef] = []
var _catching_up: bool = false
var upgrades: WorkerUpgradeState = WorkerUpgradeState.new()
var upgrade_shop: WorkerUpgradeService = WorkerUpgradeService.new(self)
var legacy_baskets: Array = []
var crop_policy: CropWorkerPolicy
var navigation: WorkerNavigationSystem
const ONLINE_BUDGET_USEC: int = 2000
var _event_open: bool = false
var _event_row: int = 0
var _budget_frame: int = -1
var _budget_spent_usec: int = 0
var _online_pending: bool = false
## Opt-in counters for the isolated rendered benchmark.
var profiling: bool = false
var scheduler_usec: int = 0
var commit_usec: int = 0
var commit_max_usec: int = 0

## Build once per query/event, rather than scanning every worker for every tile.
## Snapshots deliberately rebuild from records: restore and test fixtures can edit them.
func reservations(except_id: String = "") -> Dictionary:
	var result: Dictionary = {"cells": {}, "targets": {}, "items": {}}
	for other: Dictionary in records:
		if other.id == except_id or not running(other):
			continue
		var job: Dictionary = other.task
		var key: String = target_key(job)
		if not key.is_empty():
			result.targets[key] = true
		for cell: Vector2i in WorkerAreaPolicy.task_cells(job):
			result.cells[cell] = true
		if other.role == "crop":
			for cell: Vector2i in crop_automation.prepared_cells(other.id):
				result.cells[cell] = true
		if job.get("kind", "") in ["till", "plant", "fertilize", "treat_pests", "treat_weeds", "cure_animal"]:
			var item: String = String(job.get("item", ""))
			result.items[item] = int(result.items.get(item, 0)) + WorkerAreaPolicy.item_count(job)
	return result

func _ready() -> void:
	bridge = WorkerWorldBridge.new(world)
	crop_policy = CropWorkerPolicy.new(world)
	navigation = WorkerNavigationSystem.new()
	navigation.world = world
	navigation.name = "Navigation"
	add_child(navigation)
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

func records_for(role: String, employed_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in records:
		if row.role == role and (not employed_only or row.employed):
			result.append(row)
	return result

func record_for(id: String) -> Dictionary:
	for row: Dictionary in records:
		if row.id == id:
			return row
	return {}

# Role lookup remains for single-role callers; individual operations use IDs.
func record(key: String) -> Dictionary:
	if not key in WorkerRole.ROLES:
		return record_for(key)
	var rows: Array[Dictionary] = records_for(key, true)
	if rows.is_empty():
		rows = records_for(key)
	return rows[0] if not rows.is_empty() else {}

func actor_for(key: String) -> WorkerActor:
	var row: Dictionary = record(key)
	return actors.get(row.get("id", "")) as WorkerActor

func bag_for(key: String) -> InventoryComponent:
	var actor: WorkerActor = actor_for(key)
	return actor.basket if is_instance_valid(actor) else null

func worker_number(id: String) -> int:
	var row: Dictionary = record_for(id)
	if row.is_empty():
		return 0
	return int(row.slot)

func task_duration(job: Dictionary, actor: WorkerActor) -> float:
	return float(job.get("duration", actor.definition.work_seconds))

func target_key(job: Dictionary) -> String:
	return WorkerRole.target_key(job)

func target_available(row: Dictionary, job: Dictionary) -> bool:
	var key: String = target_key(job)
	if key.is_empty():
		return true
	var held: Dictionary = reservations(String(row.id))
	if not job.has("cells") and held.targets.has(key):
		return false
	for cell: Vector2i in WorkerAreaPolicy.task_cells(job):
		if held.cells.has(cell):
			return false
	return true

func reserved_items(item_id: String, except_id: String = "") -> int:
	var count: int = 0
	for row: Dictionary in records:
		if row.id != except_id and running(row) and not row.task.is_empty() and row.task.get("kind", "") in ["till", "plant", "fertilize", "treat_pests", "treat_weeds", "cure_animal"] and row.task.get("item", "") == item_id:
			count += WorkerAreaPolicy.item_count(row.task)
	return count

func next_slot(role: String) -> int:
	var used: Dictionary = {}
	for row: Dictionary in records_for(role):
		used[int(row.slot)] = true
	for slot: int in range(1, int(WorkerRole.LIMITS[role]) + 1):
		if not used.has(slot):
			return slot
	return 0

func spawn_point(role: String, zone: String, except_id: String = "") -> Vector2:
	var base: Vector2 = bridge.home(role, zone)
	if role != "crop":
		return base
	var cell: Vector2i = world.farming.world_to_cell(base)
	for offset: int in range(16):
		var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell + Vector2i(offset % 3, floori(float(offset) / 3.0))))
		var occupied: bool = false
		for id: String in actors:
			if id != except_id and (actors[id] as WorkerActor).global_position.distance_to(point) < 12:
				occupied = true
		if not occupied:
			return point
	return base

func output_inventory() -> InventoryComponent:
	return world.storages.inventory("produce_warehouse")

func feed_inventory(key: String) -> InventoryComponent:
	return world.storages.inventory("farm_supply_storage")

func _warehouse_changed(id: String) -> void:
	bridge.invalidate_ranch()
	if not busy:
		legacy_pending = true
	for row: Dictionary in records:
		request_scan(row.role)

func _drain_legacy_products() -> void:
	legacy_pending = false
	_drain_archived_baskets()
	for row: Dictionary in records:
		world.storages.import_worker_products(bag_for(row.id))
		world.storages.import_worker_products(bag_for(row.id), true)

func _drain_archived_baskets() -> void:
	var remaining: Array = []
	if not legacy_baskets.is_empty() and world.storages.catalog == null:
		world.storages.catalog = SaveCatalog.new()
	for slots: Array in legacy_baskets:
		var bag: InventoryComponent = InventoryComponent.new()
		bag.slot_count = slots.size()
		bag.starting_tools = false
		bag.stack_cap = 100
		var stacks: Array[Dictionary] = []
		for slot: Dictionary in slots:
			stacks.append({"item": world.storages.catalog.items.get(slot.item), "count": int(slot.count), "tiers": slot.tiers.duplicate()})
		bag.restore_slots(stacks)
		world.storages.import_worker_products(bag)
		world.storages.import_worker_products(bag, true)
		var saved: Array = []
		var count: int = 0
		for index: int in range(bag.slot_count):
			var slot: Dictionary = bag.slot(index)
			count += int(slot.count)
			saved.append({"item": String(slot.item.item_id) if slot.item != null else "", "count": int(slot.count), "tiers": slot.tiers.duplicate()})
		if count > 0:
			remaining.append(saved)
		bag.free()
	legacy_baskets = remaining

func available() -> bool:
	return world.tool_upgrades != null and world.tool_upgrades.profile_ready and not world.storages.busy

func unlock_error(role: String) -> String:
	return "Unlock at least 12 farmland blocks." if world.land.state.unlocked_blocks < 12 else ""

func hire(role: String, zone: String = "") -> String:
	if busy or not available() or not role in WorkerRole.ROLES:
		return "Workers are unavailable."
	settle(world.farming.time_manager.now())
	var error: String = unlock_error(role)
	if not error.is_empty():
		return error
	if records_for(role, true).size() >= int(WorkerRole.LIMITS[role]):
		return "The worker team is full ({limit}/{limit}).".format({"limit": WorkerRole.LIMITS[role]})
	zone = ""
	var row: Dictionary = {}
	for previous: Dictionary in records_for(role):
		if not previous.employed:
			row = previous
			break
	var wage: int = int(WorkerRole.WAGES[role]) if role in trial_used else 0
	if world.player.wallet.balance < wage:
		return "Not enough coins for today's wage."
	busy = true
	var now: float = simulated_at
	var day: int = world.weather.schedule.day_at(now)
	if row.is_empty():
		if role == "crop" and records_for("crop").is_empty():
			crop_automation.auto_plant = true
			crop_automation.revision += 1
		row = {"id": "worker_" + Crypto.new().generate_random_bytes(12).hex_encode(), "role": role, "slot": next_slot(role), "zone": zone, "employed": true, "active": true, "hire_order": next_order, "paid_through_day": day, "last_wage_day": day, "position": WorkerRole.pair(spawn_point(role, zone, String(row.get("id", "")))), "task": {}, "wake_at": now, "water_units": 0, "paused_at": 0.0, "patrol_index": 0}
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
		row.position = WorkerRole.pair(spawn_point(role, zone, String(row.get("id", ""))))
		(actors[row.id] as WorkerActor).global_position = WorkerRole.point(row.position)
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
	if row.role == "crop":
		crop_automation.prepared.erase(row.id)
	request_scan(row.role)
	# Keep the basket and trial flag. Rehiring never reissues a free shift.
	changed.emit()
	busy = false
	return ""

func set_active(id: String, active: bool) -> String:
	if busy or not available(): return "Workers are unavailable."
	settle(world.farming.time_manager.now())
	var row: Dictionary = record_for(id)
	if row.is_empty() or not row.employed: return "No worker hired."
	if active and row.paid_through_day < row.last_wage_day: return "Pay the worker's next shift before resuming."
	if bool(row.active) == active: return ""
	row.active = active
	if active:
		_resume_task(row, world.farming.time_manager.now())
	else:
		row.paused_at = world.farming.time_manager.now()
	changed.emit()
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
		var amount: int = mini(int(stack.count), target.capacity_for(item, ItemQuality.stack_tier(stack.tiers)))
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
	actors[row.id] = actor
	var access: WorkerBoard = (load("res://scenes/workers/worker_board.tscn") as PackedScene).instantiate() as WorkerBoard
	access.role = row.role
	access.worker_access = true
	access.worker_id = row.id
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
		if not _catching_up and bridge.present_care_effects:
			wage_paid.emit()
	elif previously_active and float(row.paused_at) == 0.0:
		row.paused_at = simulated_at
	row.wake_at = simulated_at

func blocked(role: String, now: float) -> void:
	var row: Dictionary = record(role)
	if row.is_empty() or busy:
		return
	row.position = WorkerRole.pair((actor_for(role) as WorkerActor).global_position)
	var task: Dictionary = row.task
	if task.is_empty():
		return
	var attempt: int = int(task.get("attempt", 0)) + 1
	if attempt <= 4:
		var offsets: Array[Vector2] = [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]
		var point: Vector2 = WorkerRole.point(task.base_point) + offsets[attempt - 1]
		if String(task.get("kind", "")) == "patrol" or bridge.zone_contains(row, point):
			task.point = WorkerRole.pair(point)
			task.attempt = attempt
			task.finish_at = now + WorkerRole.point(row.position).distance_to(point) / (actor_for(role) as WorkerActor).movement.speed + task_duration(task, actor_for(role))
			task.work_at = task.finish_at - task_duration(task, actor_for(role))
			return
	blocked_targets[String(row.id) + ":" + String(task.id)] = now + 120.0
	waiting_reasons[String(row.id)] = "Cannot reach the target. Will try another job."
	if row.role == "crop" and task.kind == "plant":
		crop_automation.prepared.erase(row.id)
	row.task = {}
	row.wake_at = now
	request_scan(row.role)

func _before_tick(timestamp: float) -> void:
	if not available() or records.is_empty() or timestamp - simulated_at < 0.25:
		return
	# Catch up workers before other world systems consume this same time span.
	var offline: bool = timestamp - simulated_at > 5.0 and not _event_open
	if offline:
		advance(timestamp, true)
	else:
		_advance_online(timestamp)

func _advance_online(timestamp: float) -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_spent_usec = 0
	var remaining: int = ONLINE_BUDGET_USEC - _budget_spent_usec
	if remaining <= 0:
		return
	var started: int = Time.get_ticks_usec()
	_online_pending = not advance(timestamp, false, remaining)
	_budget_spent_usec += Time.get_ticks_usec() - started
	if profiling:
		scheduler_usec += Time.get_ticks_usec() - started

func _process(_delta: float) -> void:
	if (_event_open or _online_pending) and available() and not busy:
		_advance_online(world.farming.time_manager.now())

func settle(now: float) -> void:
	advance(now, now - simulated_at > 5.0)

## A budget yields only between complete events. The next call resumes at the
## next event, including when that event is exactly the requested endpoint.
func advance(until: float, offline: bool = true, budget_usec: int = 0) -> bool:
	if busy or world.storages.busy or not is_finite(until) or until < simulated_at:
		return true
	if records.is_empty():
		simulated_at = until
		return true
	busy = true
	bridge.present_care_effects = not offline
	var started: int = Time.get_ticks_usec()
	crop_policy.deadline_usec = started + budget_usec if not offline and budget_usec > 0 else 0
	var clock: FarmClock = world.farming.time_manager
	var previous: float = clock.simulation_timestamp
	if not _event_open:
		records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hire_order) < int(b.hire_order))
	while simulated_at <= until:
		clock.simulation_timestamp = simulated_at
		if not _event_open:
			if legacy_pending:
				_drain_legacy_products()
			bridge.sync(simulated_at, offline)
			_drain_pickups()
			_event_row = 0
			_event_open = true
		var day: int = world.weather.schedule.day_at(simulated_at)
		for index: int in range(_event_row, records.size()):
			if not offline and budget_usec > 0 and index > _event_row and Time.get_ticks_usec() - started >= budget_usec:
				_event_row = index
				clock.simulation_timestamp = previous
				busy = false
				crop_policy.deadline_usec = 0
				return false
			var row: Dictionary = records[index]
			_pay(row, day)
			if not running(row):
				continue
			var actor: WorkerActor = actors[row.id] as WorkerActor
			if not row.task.is_empty() and row.task.kind == "cure_animal":
				if not bridge.refresh_animal_task(row, offline):
					row.task = {}
					row.wake_at = simulated_at + 0.5
			# Animal demand can arise while travelling to a lower-priority plot.
			# Keep prepared soil; an interrupted job has not spent its supplies.
			if not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"] and float(row.task.finish_at) > simulated_at:
				var urgent_held: Dictionary = reservations(String(row.id))
				for option: Dictionary in bridge.ranch_candidates(row, feed_inventory(row.id), urgent_held):
					if float(blocked_targets.get(String(row.id) + ":" + String(option.id), 0)) <= simulated_at:
						row.position = WorkerRole.pair(actor.global_position)
						row.task = {}
						row.wake_at = simulated_at
						break
			var task: Dictionary = row.task
			if not task.is_empty() and float(task.finish_at) <= simulated_at + 0.00001:
				var target: Vector2 = WorkerRole.point(task.point)
				if not offline and actor.global_position.distance_to(target) > 3.0:
					task.finish_at = simulated_at + 0.25
				else:
					row.position = task.point.duplicate()
					if offline:
						actor.global_position = target
					var commit_started: int = Time.get_ticks_usec() if profiling else 0
					if task.has("cells"):
						WorkerAreaPolicy.commit_next(self, row, task)
					else:
						bridge.commit(row, feed_inventory(row.id), task)
					if profiling:
						var spent: int = Time.get_ticks_usec() - commit_started
						commit_usec += spent
						commit_max_usec = maxi(commit_max_usec, spent)
					if task.has("cells") and int(task.cursor) < task.cells.size():
						task.finish_at = simulated_at + 0.00001
					else:
						row.task = {}
					row.wake_at = simulated_at + (bridge.rest_seconds(row) if String(task.get("kind", "")) == "patrol" else 0.0)
			if row.task.is_empty() and float(row.wake_at) <= simulated_at:
				if not offline:
					row.position = WorkerRole.pair(actor.global_position)
				# Full crop/plant scan is exclusively for workers that need a task.
				var options: Array[Dictionary] = []
				var held: Dictionary = reservations(String(row.id))
				crop_policy.query_pending = false
				var candidates: Array[Dictionary] = bridge.candidates(row, feed_inventory(row.id))
				if crop_policy.query_pending:
					_event_row = index
					clock.simulation_timestamp = previous
					busy = false
					crop_policy.deadline_usec = 0
					return false
				for option: Dictionary in candidates:
					var cell_free: bool = not option.has("cell") or not held.cells.has(Vector2i(int(option.cell[0]), int(option.cell[1])))
					if cell_free and not held.targets.has(target_key(option)) and float(blocked_targets.get(String(row.id) + ":" + String(option.id), 0)) <= simulated_at and bridge.zone_contains(row, WorkerRole.point(option.point)):
						options.append(option)
				WorkerRole.apply_priorities(options, crop_automation.priority_mode)
				if options.is_empty() and not candidates.is_empty() and not waiting_reasons.has(String(row.id)):
					waiting_reasons[String(row.id)] = "Work targets are reserved or blocked. Waiting for another opportunity."
				var chosen: Dictionary = WorkerRole.choose(options, WorkerRole.point(row.position))
				var wake: float = bridge.next_wake(row, feed_inventory(row.id), simulated_at)
				if chosen.is_empty():
					var stroll: Vector2 = bridge.patrol_point(row)
					chosen = {"kind": "patrol", "id": "patrol:%d_%d" % [roundi(stroll.x), roundi(stroll.y)], "point": WorkerRole.pair(stroll), "priority": 9}
				if not chosen.is_empty() and (String(chosen.get("kind", "")) == "patrol" or bridge.zone_contains(row, WorkerRole.point(chosen.point))):
					WorkerAreaPolicy.expand(self, row, chosen)
					chosen["duration"] = upgrades.duration(actor.definition.work_seconds, String(chosen.kind))
					chosen["base_point"] = chosen.point.duplicate()
					chosen["attempt"] = 0
					chosen["work_at"] = simulated_at + WorkerRole.point(row.position).distance_to(WorkerRole.point(chosen.point)) / actor.movement.speed + actor.movement.speed / actor.movement.acceleration
					chosen["finish_at"] = chosen.work_at + task_duration(chosen, actor)
					if chosen.kind == "patrol":
						chosen.finish_at = maxf(float(chosen.finish_at), minf(simulated_at + 60.0, wake))
					row.task = chosen
				else:
					row.wake_at = bridge.next_wake(row, feed_inventory(row.id), simulated_at)
		_event_open = false
		_event_row = 0
		if simulated_at >= until:
			break
		var next: float = minf(until, world.weather.schedule.dawn_at(day + 1))
		for row: Dictionary in records:
			if running(row):
				next = minf(next, float(row.task.finish_at) if not row.task.is_empty() else float(row.wake_at))
				if not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"]:
					next = minf(next, bridge.next_wake(row, feed_inventory(row.id), simulated_at))
		simulated_at = minf(until, maxf(simulated_at + 0.00001, next))
		if budget_usec > 0 and Time.get_ticks_usec() - started >= budget_usec:
			clock.simulation_timestamp = previous
			busy = false
			crop_policy.deadline_usec = 0
			return false
	clock.simulation_timestamp = previous
	busy = false
	crop_policy.deadline_usec = 0
	return true

func advance_async(until: float, budget_usec: int = 32000) -> void:
	_catching_up = true
	var old_defer_edges: bool = world.farming.defer_soil_edges
	world.farming.defer_soil_edges = true
	var start: float = simulated_at
	var clock: FarmClock = world.farming.time_manager
	var previous: float = clock.simulation_timestamp
	while true:
		var complete: bool = advance(until, true, maxi(1, budget_usec))
		# Deferred pickup/storage notifications run during the yielded frame.
		# Their scans must use the current event time, never the saved checkpoint.
		clock.simulation_timestamp = simulated_at
		catch_up_progress.emit(1.0 if complete else clampf((simulated_at - start) / maxf(0.00001, until - start), 0.0, 1.0))
		if complete:
			break
		await get_tree().process_frame
	clock.simulation_timestamp = previous
	_catching_up = false
	world.farming.defer_soil_edges = old_defer_edges
	if not old_defer_edges:
		world.farming.flush_soil_edges()

func capture(now: float) -> Dictionary:
	settle(now)
	var rows: Array = []
	for row: Dictionary in records:
		var copy: Dictionary = row.duplicate(true)
		copy["position"] = WorkerRole.pair((actors[row.id] as WorkerActor).global_position)
		if not copy.task.is_empty() and running(row):
			var remaining: float = WorkerRole.point(copy.position).distance_to(WorkerRole.point(copy.task.point))
			if remaining > 3.0:
				copy.task.work_at = maxf(float(copy.task.work_at), now + remaining / (actors[row.id] as WorkerActor).movement.speed)
				copy.task.finish_at = maxf(float(copy.task.finish_at), float(copy.task.work_at) + task_duration(copy.task, actors[row.id] as WorkerActor))
		copy["basket"] = []
		var bag: InventoryComponent = bag_for(row.id)
		for i: int in range(bag.slot_count):
			var stack: Dictionary = bag.slot(i)
			copy.basket.append({"item": String(stack.item.item_id) if stack.item != null else "", "count": int(stack.count), "tiers": stack.tiers.duplicate()})
		rows.append(copy)
	return {"rows": rows, "trial_used": trial_used.duplicate(), "next_order": next_order, "simulated_at": simulated_at, "crop_automation": crop_automation.capture(), "upgrades": upgrades.levels.duplicate(), "legacy_baskets": legacy_baskets.duplicate(true)}

func restore(data: Dictionary, catalog: SaveCatalog) -> void:
	busy = true
	_event_open = false
	_event_row = 0
	_online_pending = false
	navigation.reset()
	for actor: WorkerActor in actors.values():
		actor.free()
	actors.clear()
	blocked_targets.clear()
	waiting_reasons.clear()
	# Re-sync trough tracking to live stocks so a restored timeline fires the
	# same rescans as a single-jump run from the same checkpoint.
	trough_levels.clear()
	for pen: AnimalPen in bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				trough_levels[child.get_instance_id()] = int(child.stock)
	bridge.storage_waiting.clear()
	bridge.invalidate_crops()
	records.clear()
	trial_used.assign(data.trial_used)
	next_order = int(data.next_order)
	simulated_at = float(data.simulated_at)
	upgrades.levels = data.get("upgrades", WorkerUpgradeState.fresh()).duplicate()
	legacy_baskets = data.get("legacy_baskets", []).duplicate(true)
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
		bag_for(row.id).restore_slots(stacks)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hire_order) < int(b.hire_order))
	_drain_legacy_products()
	busy = false

func request_scan(role: String) -> void:
	for row: Dictionary in records_for(role):
		row.wake_at = minf(float(row.wake_at), world.farming.time_manager.now())
		if not row.task.is_empty() and row.task.kind == "patrol":
			row.task = {}

func _node_added(node: Node) -> void:
	if not world.is_ancestor_of(node):
		return
	if node is PerennialTree:
		request_scan("crop")
	elif node is ItemPickup:
		_pending_pickups.append(weakref(node))
		_flush_pickups.call_deferred()

func _flush_pickups() -> void:
	if not busy and not _catching_up:
		_drain_pickups()

func _drain_pickups() -> void:
	var pending: Array[WeakRef] = _pending_pickups
	_pending_pickups = []
	for reference: WeakRef in pending:
		var node: Node = reference.get_ref() as Node
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			_pickup_added(node)

func _pickup_added(node: Node) -> void:
	if not is_instance_valid(node) or not node is ItemPickup or not world.is_ancestor_of(node):
		return
	for row: Dictionary in records:
		if bridge.zone_contains(row, (node as ItemPickup).global_position):
			request_scan(row.role)

func _trough_changed(stock: int, trough: AnimalTrough) -> void:
	bridge.invalidate_ranch()
	var key: int = trough.get_instance_id()
	if int(trough_levels.get(key, stock)) != stock:
		trough_levels[key] = stock
		request_scan("crop")

func running(row: Dictionary) -> bool:
	return bool(row.employed) and bool(row.active) and not (row.role == "crop" and crop_automation.paused)

func configure_priority(mode: String) -> bool:
	if busy or not mode in WorkerRole.PRIORITY_MODES:
		return false
	crop_automation.priority_mode = mode
	request_scan("crop")
	changed.emit()
	return true

func _resume_task(row: Dictionary, timestamp: float) -> void:
	if float(row.paused_at) > 0 and not row.task.is_empty():
		var gap: float = maxf(0, timestamp - float(row.paused_at))
		row.task.work_at += gap
		row.task.finish_at += gap
	row.paused_at = 0.0
	if not row.task.is_empty() and not target_available(row, row.task):
		row.task = {}
	if row.role == "crop":
		for prepared: Vector2i in crop_automation.prepared_cells(row.id):
			if LandExpansionState.REGION.has_point(prepared) and not target_available(row, crop_policy.task("plant", prepared, 4)):
				crop_automation.remove_prepared(row.id, prepared)

func configure_crop(plant: bool, fertilizer: bool, pause: bool) -> String:
	if busy or not available() or records_for("crop", true).is_empty():
		return "Workers are unavailable."
	settle(world.farming.time_manager.now())
	busy = true
	var changed_options: bool = plant != crop_automation.auto_plant or fertilizer != crop_automation.auto_fertilize
	if changed_options:
		crop_automation.revision += 1
	for row: Dictionary in records_for("crop"):
		if changed_options and not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"]:
			row.task = {}
		if pause and not crop_automation.paused and float(row.paused_at) == 0.0:
			row.paused_at = simulated_at
		elif not pause and crop_automation.paused and row.active:
			_resume_task(row, simulated_at)
		row.wake_at = simulated_at
	crop_automation.auto_plant = plant
	crop_automation.auto_fertilize = fertilizer
	crop_automation.paused = pause
	request_scan("crop")
	changed.emit()
	busy = false
	return ""

func _soil_changed(cell: Vector2i, _old: int, current: int) -> void:
	bridge.invalidate_ranch()
	crop_policy.soil_changed(cell, current)
	request_scan("crop")

func _crop_planted(cell: Vector2i, _crop: Crop) -> void:
	bridge.invalidate_crops()
	crop_policy.cancel_searches()
	crop_automation.forget_crop(cell)
	request_scan("crop")

func _crop_harvested(cell: Vector2i) -> void:
	bridge.invalidate_crops()
	crop_policy.cancel_searches()
	crop_automation.forget_crop(cell)
	request_scan("crop")

func configure_wait_for_care(enabled: bool) -> bool:
	if busy or not available():
		return false
	settle(world.farming.time_manager.now())
	busy = true
	crop_automation.wait_for_care = enabled
	crop_automation.revision += 1
	for row: Dictionary in records_for("crop"):
		if not row.task.is_empty() and row.task.kind == "harvest":
			row.task = {}
		row.wake_at = world.farming.time_manager.now()
	request_scan("crop")
	changed.emit()
	busy = false
	return true
