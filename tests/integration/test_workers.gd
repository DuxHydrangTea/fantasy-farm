extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
var world: FarmWorld
var service: WorkerService
var now: float
const FIXED_TIME: float = 1793155000.0
var _old_clock_source: Callable
var _old_clock_floor: float

func before_each() -> void:
	_old_clock_source = TimeManager.clock_source
	_old_clock_floor = TimeManager._last_timestamp
	TimeManager._last_timestamp = FIXED_TIME
	TimeManager.clock_source = func() -> float: return FIXED_TIME
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	service = world.workers
	now = world.farming.time_manager.now()
	var fixed_now: float = now
	world.farming.time_manager.clock_source = func() -> float: return fixed_now
	world.weather.schedule.seed = 12345
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(1000000)
	world.trees.reset()
	# The fixture spans ten columns; the current save schema requires ownership.
	assert_true(world.tree_plot_upgrades.state.restore({"fruit": 10, "timber": 1}))
	for index: int in range(10):
		var cell: Vector2i = Vector2i(12 + index * 3, 61)
		assert_true(TreePlotUpgradeState.allows(world.tree_plot_upgrades.state.capture(), cell, TreeDefinition.Kind.FRUIT))
		var tree: FruitTree = world.trees.create_tree(cell, world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1.0
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds if index == 0 else 0.0
		tree.refresh(now)
	await wait_process_frames(2)


func after_each() -> void:
	TimeManager.clock_source = _old_clock_source
	TimeManager._last_timestamp = _old_clock_floor


func _checkpoint_ok(adapter: WorldStateAdapter, snapshot: Dictionary) -> bool:
	var checked: Dictionary = SaveSchema.validate(snapshot, adapter.catalog)
	assert_true(checked.ok, "Checkpoint validation: " + str(checked))
	if not checked.ok:
		return false
	var preflight: Dictionary = adapter.preflight(snapshot)
	assert_true(preflight.ok, "Checkpoint preflight: " + str(preflight))
	return bool(preflight.ok)

func _restore_ok(adapter: WorldStateAdapter, snapshot: Dictionary, timestamp: float) -> bool:
	var restored: Dictionary = adapter.restore(snapshot, timestamp)
	assert_true(restored.ok, "Checkpoint restore: " + str(restored))
	return bool(restored.ok)

func test_hire_harvest_goes_directly_to_warehouse_not_worker_or_player_bag() -> void:
	assert_eq(service.hire("orchard"), "")
	assert_eq(service.hire("orchard"), "This role is already hired.")
	service.advance(now + 20.0)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	assert_eq(service.output_inventory().get_slot_count(0), 300)
	assert_eq(service.bag_for("orchard").count_item(APPLE.item_id), 0)
	assert_eq(world.player.selection.inventory.count_item(APPLE.item_id), 0)
	assert_eq(service.transfer("orchard", world.player.selection.inventory, false, false), 0)

func test_free_shift_only_once_and_unpaid_pause_at_dawn() -> void:
	assert_eq(service.hire("orchard"), "")
	assert_eq(world.player.wallet.balance, 1000000)
	assert_eq(service.dismiss("orchard"), "")
	assert_eq(service.hire("orchard"), "")
	assert_eq(world.player.wallet.balance, 998200)
	world.player.wallet.set_balance(0)
	var dawn: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	service.advance(dawn)
	assert_false(service.record("orchard").active)
	assert_true(service.record("orchard").employed)
	world.player.wallet.set_balance(1800)
	service.advance(dawn + 86400.0)
	assert_true(service.record("orchard").active)
	assert_eq(world.player.wallet.balance, 0)

func test_warehouse_full_preserves_entire_tree_yield_and_task_budget() -> void:
	service.hire("orchard")
	var warehouse: InventoryComponent = service.output_inventory()
	warehouse.add(APPLE, warehouse.capacity_for(APPLE) - 200)
	var initial: int = warehouse.count_item(APPLE.item_id)
	service.advance(now + 20.0)
	assert_eq(warehouse.count_item(APPLE.item_id), initial)
	assert_true((world.trees.trees[Vector2i(12, 61)] as FruitTree).has_fruit())
	assert_true(bool(service.bridge.storage_waiting.get("orchard", false)))

func test_v37_migration_unifies_roles_without_loss() -> void:
	world.land.state.restore_columns(12, 4)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	assert_eq(service.hire("crop"), "")
	assert_eq(service.hire("crop"), "")
	var old: Dictionary = adapter.capture("worker_test", 1, now)
	var rows: Array = old.workers.rows
	rows[0].role = "ranch"
	rows[0].zone = "pen_x"
	rows[0].task = {"kind": "feed", "id": "trough_1", "point": [776.0, 488.0], "base_point": [776.0, 488.0], "attempt": 0, "work_at": now, "finish_at": now + 2.0}
	if rows.size() > 1:
		rows[1].role = "orchard"
	old.workers.trial_used = ["ranch"]
	old.version = 37
	var migrated: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(migrated.ok, str(migrated))
	assert_eq(int(migrated.snapshot.version), SaveSchema.VERSION)
	var unified: Array = migrated.snapshot.workers.rows
	assert_eq(unified.size(), rows.size(), "No worker lost")
	for row: Dictionary in unified:
		assert_eq(String(row.role), "crop")
		assert_eq(String(row.zone), "")
	var slots: Dictionary = {}
	for row: Dictionary in unified:
		slots[int(row.slot)] = true
	assert_eq(slots.size(), unified.size(), "Slots unique 1..N")
	assert_true("crop" in migrated.snapshot.workers.trial_used)
	assert_eq(String(unified[0].task.kind), "feed", "Active ranch task survives")
	var preflight: Dictionary = adapter.preflight(migrated.snapshot)
	assert_true(bool(preflight.ok), "Preflight accepts unified rows without pens: " + str(preflight))

func test_worker_limit_fifteen_enforced_everywhere() -> void:
	world.land.state.restore_columns(12, 4)
	for i: int in range(15):
		assert_eq(service.hire("crop"), "")
	assert_ne(service.hire("crop"), "", "16th hire must be rejected")

func test_unified_unlock_and_spawn() -> void:
	world.land.state.restore_columns(4, 4)
	assert_true(not service.unlock_error("crop").is_empty(), "12-column gate still gates")
	world.land.state.restore_columns(12, 4)
	assert_eq(service.unlock_error("crop"), "")
	var first: Vector2 = service.spawn_point("crop", "")
	var second: Vector2 = service.spawn_point("crop", "pen_x")
	assert_true(first.distance_to(second) < 0.01, "Zone no longer moves the spawn")

func test_unified_worker_feeds_troughs_and_harvests_trees() -> void:
	world.land.state.restore_columns(12, 4)
	for pen: AnimalPen in service.bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				(child as AnimalTrough).stock = 0
	assert_eq(service.hire("crop"), "")
	service.advance(now + 0.5)
	var row: Dictionary = service.record("crop")
	assert_false(row.task.is_empty())
	assert_true(String(row.task.get("kind")) in ["feed", "fetch_water", "water_trough", "fruit"],
		"Unified worker takes trough or orchard work, got " + String(row.task.get("kind")))

func test_v22_migration_and_worker_basket_roundtrip_offline() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var old: Dictionary = adapter.capture("worker_test", 1, now)
	old.version = 22
	old.erase("workers")
	var migrated: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(migrated.ok, str(migrated))
	assert_eq(int(migrated.snapshot.version), SaveSchema.VERSION)
	assert_false(old.has("workers"))
	service.hire("orchard")
	var saved: Dictionary = adapter.capture("worker_test", 1, now)
	if not _checkpoint_ok(adapter, saved) or not _restore_ok(adapter, saved, now + 20.0):
		return
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	var second: Dictionary = adapter.capture("worker_test", 2, now + 20.0)
	if not _checkpoint_ok(adapter, second) or not _restore_ok(adapter, second, now + 20.0):
		return
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	second.workers.rows[0].basket[0].count = 101
	assert_false(adapter.restore(second, now + 20.0).ok)

func test_authored_board_and_worker_support_e_and_modal_lifecycle() -> void:
	var board: WorkerBoard = world.get_node("OrchardWorkers") as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0, 20)
	assert_true(board.open_shop(world.player))
	var menu: WorkerMenu = board.menu as WorkerMenu
	assert_null(board.shop_ui)
	assert_true(menu.is_open)
	menu._hire()
	assert_false(service.record("orchard").is_empty())
	menu.close(false)
	assert_false(world.player.selection.is_menu_open())
	var actor: WorkerActor = service.actor_for("orchard")
	var access: WorkerBoard = actor.get_node("ManagementSign") as WorkerBoard
	world.player.global_position = actor.global_position + Vector2(0, 20)
	assert_true(access.open_shop(world.player))
	assert_false((access.menu as WorkerMenu).collect_button.visible, "No recovery action is shown for an empty old basket")

func test_single_ranch_worker_services_food_and_water_in_every_pen() -> void:
	var pens: Array[AnimalPen] = service.bridge.pens()
	assert_gte(pens.size(), 3)
	assert_eq(service.hire("ranch", String(pens[0].persistent_id)), "")
	var bag: InventoryComponent = service.feed_inventory("ranch")
	bag.add(preload("res://items/feeds/livestock_feed.tres"), 100)
	bag.add(preload("res://items/feeds/poultry_feed.tres"), 100)
	var row: Dictionary = service.record("ranch")
	for pen: AnimalPen in pens:
		var food: AnimalTrough
		var water: AnimalTrough
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				if child.kind == AnimalTrough.Kind.FOOD:
					food = child as AnimalTrough
				else:
					water = child as AnimalTrough
		assert_not_null(food)
		assert_not_null(water)
		if food == null or water == null:
			continue
		food.stock = 0
		water.stock = 0
		row.water_units = 30
		var tasks: Array[Dictionary] = service.bridge.candidates(row, bag)
		var found_food: bool = false
		var found_water: bool = false
		service.busy = true
		for task: Dictionary in tasks:
			if task.id == String(food.persistent_id) and task.kind == "feed":
				found_food = service.bridge.commit(row, bag, task)
			if task.id == String(water.persistent_id) and task.kind == "water_trough":
				found_water = service.bridge.commit(row, bag, task)
		service.busy = false
		assert_true(found_food, "Worker should feed " + String(pen.persistent_id))
		assert_true(found_water, "Worker should water " + String(pen.persistent_id))
		assert_gt(food.stock, 0)
		assert_gt(water.stock, 0)

func test_ranch_worker_physically_travels_between_pens_to_feed() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	var pens: Array[AnimalPen] = service.bridge.pens()
	assert_eq(service.hire("ranch", String(pens[0].persistent_id)), "")
	var row: Dictionary = service.record("ranch")
	var actor: WorkerActor = service.actor_for(row.id)
	actor.behaviour.set_physics_process(false)
	var food: AnimalTrough
	for pen: AnimalPen in pens:
		for node: Node in pen.get_children():
			if node is AnimalTrough:
				node.stock = node.capacity
				if pen == pens[1] and node.kind == AnimalTrough.Kind.FOOD:
					food = node as AnimalTrough
	assert_not_null(food)
	if food == null:
		return
	food.stock = 0
	service.feed_inventory("ranch").add(food.feed_item, 10)
	var time: Array[float] = [now]
	world.farming.time_manager.clock_source = func() -> float: return time[0]
	await wait_physics_frames(2)
	for frame: int in range(900):
		time[0] = now + float(frame + 1) / 60.0
		if frame % 15 == 0:
			service.advance(time[0], false)
		actor.behaviour._step(1.0 / 60.0)
		if frame % 300 == 0:
			print("RANCH_ROUTE frame=", frame, " position=", actor.global_position, " task=", row.task, " nav=", actor.behaviour._navigation.is_navigating if actor.behaviour._navigation != null else false)
		if food.stock > 0:
			break
		await wait_physics_frames(1)
	assert_gt(food.stock, 0, "Worker must physically reach the other pen; position=%s task=%s" % [actor.global_position, row.task])

func test_ranch_feed_and_water_use_apis_and_separate_transfer_commands() -> void:
	var pen: AnimalPen = service.bridge.pens()[0]
	assert_eq(service.hire("ranch", String(pen.persistent_id)), "")
	var bag: InventoryComponent = service.bag_for("ranch")
	var water: AnimalTrough
	var food: AnimalTrough
	for node: Node in pen.get_children():
		if node is AnimalTrough:
			if node.kind == AnimalTrough.Kind.FOOD:
				food = node as AnimalTrough
			else:
				water = node as AnimalTrough
	assert_not_null(food)
	assert_not_null(water)
	food.stock = 0
	water.stock = 0
	world.player.selection.inventory.add(food.feed_item, 10)
	assert_eq(service.transfer("ranch", world.player.selection.inventory, true, true), 0)
	service.feed_inventory("ranch").add(food.feed_item, 10)
	service.advance(now + 120.0)
	assert_gt(food.stock, 0)
	assert_gt(water.stock, 0)
	assert_lt(service.feed_inventory("ranch").count_item(food.feed_item.item_id), 10)
	assert_eq(bag.count_item(food.feed_item.item_id), 0)
	assert_eq(service.transfer("ranch", world.player.selection.inventory, false, false), 0)

func test_crop_waters_then_harvests_without_tilling_or_planting() -> void:
	# The unified worker harvests priority-0 fruit first; this test is about
	# crop care, so clear the orchard backlog before_starting the window.
	for tree: PerennialTree in world.trees.trees.values():
		if tree is FruitTree and not tree.removed:
			(tree as FruitTree).fruit_work = 0.0
	world.land.state.restore_columns(12, 4)
	var cell: Vector2i = Vector2i(54, 25)
	world.farming.restore_soil([{"cell": [cell.x, cell.y], "state": 1}])
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	var definition: CropDefinition = seed.crop as CropDefinition
	world.farming.restore_crop(cell, definition, now - 40.0, now + 20.0, 0.66, now)
	assert_eq(service.hire("crop"), "")
	service.advance(now + 10.0)
	assert_eq(world.farming.get_soil_state(cell), FarmingController.Soil.WET)
	assert_not_null(world.farming.get_crop(cell))
	service.advance(now + 50.0)
	assert_null(world.farming.get_crop(cell))
	assert_eq(service.output_inventory().count_item(definition.harvest_item.item_id, 1), definition.harvest_amount)
	assert_eq(world.farming.crop_cells().size(), 0)

func test_48_hour_single_jump_matches_hourly_steps_and_keeps_partial_task() -> void:
	service.hire("orchard")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	if not _checkpoint_ok(adapter, checkpoint):
		return
	service.advance(now + 172800.0)
	var single: Dictionary = service.capture(now + 172800.0)
	var warehouse: Dictionary = world.storages.capture()
	var coins: int = world.player.wallet.balance
	if not _restore_ok(adapter, checkpoint, now):
		return
	for hour: int in range(1, 49):
		service.advance(now + hour * 3600.0)
	var stepped: Dictionary = service.capture(now + 172800.0)
	assert_eq(world.storages.capture(), warehouse)
	assert_eq(stepped.rows[0].basket, single.rows[0].basket)
	assert_eq(stepped.rows[0].paid_through_day, single.rows[0].paid_through_day)
	assert_eq(world.player.wallet.balance, coins)
	assert_eq(stepped.trial_used, single.trial_used)
	assert_eq(stepped.rows[0].task, single.rows[0].task)

func test_partial_product_transfer_preserves_feed_and_full_destination() -> void:
	var pen: AnimalPen = service.bridge.pens()[0]
	service.hire("ranch", String(pen.persistent_id))
	var bag: InventoryComponent = service.bag_for("ranch")
	bag.add(APPLE, 300)
	var player_bag: InventoryComponent = world.player.selection.inventory
	for i: int in range(player_bag.slot_count):
		if player_bag.is_empty_slot(i):
			player_bag.add(APPLE, APPLE.get_stack_limit())
	assert_eq(service.transfer("ranch", player_bag, false, false), 0)
	assert_eq(bag.count_item(APPLE.item_id), 300)
	player_bag.remove(APPLE.item_id, 50)
	assert_eq(service.transfer("ranch", player_bag, false, false), 50)
	assert_eq(bag.count_item(APPLE.item_id), 250)

func test_crop_worker_load_validates_against_saved_land_not_current_land() -> void:
	world.land.state.restore_columns(12, 4)
	assert_eq(service.hire("crop"), "")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("worker_test", 1, now)
	world.land.state.restore_columns(4, 4)
	if not _checkpoint_ok(adapter, saved) or not _restore_ok(adapter, saved, now):
		return
	assert_eq(world.land.state.unlocked_columns, 12)

func test_hiring_another_role_does_not_teleport_a_blocked_online_worker() -> void:
	var clock: Array[float] = [now]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	service.hire("orchard")
	service.advance(now)
	clock[0] += 4.9
	var pen: AnimalPen = service.bridge.pens()[0]
	assert_eq(service.hire("ranch", String(pen.persistent_id)), "")
	assert_eq(service.bag_for("orchard").count_item(APPLE.item_id), 0)
	assert_false(service.record("orchard").task.is_empty())
	assert_eq(world.farming.time_manager.simulation_timestamp, -1.0)

func test_worker_commands_are_locked_through_observer_notifications() -> void:
	service.changed.connect(func() -> void:
		assert_true(service.busy)
		assert_ne(service.hire("orchard"), "")
		assert_ne(service.dismiss("orchard"), ""))
	assert_eq(service.hire("orchard"), "")
	assert_eq(service.records.size(), 1)
	assert_false(service.busy)
	assert_eq(service.dismiss("orchard"), "")
	assert_false(service.busy)

func test_ranch_two_hour_jump_matches_minute_steps() -> void:
	var pen: AnimalPen = service.bridge.pens()[0]
	service.hire("ranch", String(pen.persistent_id))
	var food: AnimalTrough
	for node: Node in pen.get_children():
		if node is AnimalTrough:
			node.stock = 0
			if node.kind == AnimalTrough.Kind.FOOD:
				food = node as AnimalTrough
	service.feed_inventory("ranch").add(food.feed_item, 10)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	if not _checkpoint_ok(adapter, checkpoint):
		return
	service.advance(now + 7200.0)
	var single: Dictionary = service.capture(now + 7200.0)
	var warehouse: Dictionary = world.storages.capture()
	var stock: float = food.available_units()
	if not _restore_ok(adapter, checkpoint, now):
		return
	for minute: int in range(1, 121):
		service.advance(now + minute * 60.0)
	assert_eq(world.storages.capture(), warehouse)
	assert_eq(service.capture(now + 7200.0).rows[0].basket, single.rows[0].basket)
	assert_almost_eq(food.available_units(), stock, 0.01)

func test_crop_two_minute_jump_matches_second_steps() -> void:
	world.land.state.restore_columns(12, 4)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	world.farming.restore_soil([{"cell": [54, 25], "state": 1}])
	world.farming.restore_crop(Vector2i(54, 25), seed.crop as CropDefinition, now - 40, now + 20, 0.66, now)
	service.hire("crop")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	if not _checkpoint_ok(adapter, checkpoint):
		return
	service.advance(now + 120)
	var single: Dictionary = service.capture(now + 120)
	var warehouse: Dictionary = world.storages.capture()
	if not _restore_ok(adapter, checkpoint, now):
		return
	for second: int in range(1, 121):
		service.advance(now + second)
	assert_eq(world.storages.capture(), warehouse)
	assert_eq(service.capture(now + 120).rows[0].basket, single.rows[0].basket)
	assert_eq(world.farming.crop_cells().size(), 0)

func test_unpaid_shift_preserves_remaining_task_and_uses_hire_order() -> void:
	world.land.state.restore_columns(12, 4)
	service.hire("orchard")
	service.hire("ranch", String(service.bridge.pens()[0].persistent_id))
	service.hire("crop")
	var day: int = world.weather.schedule.day_at(now) + 1
	service.simulated_at = world.weather.schedule.dawn_at(day)
	world.player.wallet.set_balance(4000)
	for row: Dictionary in service.records:
		service._pay(row, day)
	assert_true(service.record("orchard").active)
	assert_true(service.record("ranch").active)
	assert_false(service.record("crop").active)
	assert_eq(world.player.wallet.balance, 0)
	assert_lt(service.record("crop").paid_through_day, service.record("crop").last_wage_day)

func test_hiring_boards_do_not_occupy_existing_crop_or_tree_cells() -> void:
	var crop_board: WorkerBoard = world.get_node("CropWorkers") as WorkerBoard
	assert_false(LandExpansionState.REGION.has_point(world.farming.world_to_cell(crop_board.global_position)))
	var orchard_board: WorkerBoard = world.get_node("OrchardWorkers") as WorkerBoard
	assert_false(TreePlantation.valid_cell(world.farming.world_to_cell(orchard_board.global_position), TreeDefinition.Kind.FRUIT))

func test_finish_boundary_roundtrip_and_repeated_timestamp_collect_once() -> void:
	assert_eq(service.hire("orchard"), "")
	service.advance(now)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	if not _checkpoint_ok(adapter, checkpoint):
		return
	var task: Dictionary = checkpoint.workers.rows[0].task
	assert_eq(task.kind, "fruit")
	var finish: float = float(task.finish_at)
	assert_gt(finish, now + 0.001)
	if not _restore_ok(adapter, checkpoint, now):
		return
	assert_almost_eq(float(service.record("orchard").task.finish_at), finish, 0.000001)
	service.advance(finish - 0.001)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 0)
	service.advance(finish)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	service.advance(finish)
	service.advance(finish + 0.001)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)

func test_budgeted_catch_up_yields_and_matches_synchronous_event_results() -> void:
	assert_eq(service.hire("orchard"), "")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	var until: float = now + 120.0
	service.advance(until)
	var expected: Dictionary = service.capture(until)
	var warehouse: Dictionary = world.storages.capture()
	var coins: int = world.player.wallet.balance
	if not _restore_ok(adapter, checkpoint, now):
		return
	var clock_processing: bool = TimeManager.is_processing()
	TimeManager.set_process(false)
	var progress: Array[float] = []
	var report: Callable = func(fraction: float) -> void:
		progress.append(fraction)
		assert_eq(TimeManager.now(), service.simulated_at, "Deferred notifications must see the current event time")
	service.catch_up_progress.connect(report)
	var frame: int = Engine.get_process_frames()
	var simulation: float = TimeManager.simulation_timestamp
	await service.advance_async(until, 1)
	service.catch_up_progress.disconnect(report)
	TimeManager.set_process(clock_processing)
	assert_gt(Engine.get_process_frames(), frame, "Catch-up must allow frames to render")
	assert_gt(progress.size(), 1)
	assert_eq(progress.back(), 1.0)
	assert_eq(TimeManager.simulation_timestamp, simulation)
	assert_false(service.busy)
	assert_eq(service.capture(until), expected, "Yielding must preserve event order and endpoint tasks")
	assert_eq(world.storages.capture(), warehouse)
	assert_eq(world.player.wallet.balance, coins)

func test_dawn_boundary_and_repeated_timestamp_pay_once() -> void:
	assert_eq(service.hire("orchard"), "")
	var dawn: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	var initial: int = world.player.wallet.balance
	service.advance(dawn - 0.001)
	assert_eq(world.player.wallet.balance, initial)
	service.advance(dawn)
	assert_eq(world.player.wallet.balance, initial - int(WorkerRole.WAGES.orchard))
	service.advance(dawn)
	service.advance(dawn + 0.001)
	assert_eq(world.player.wallet.balance, initial - int(WorkerRole.WAGES.orchard))

func test_offline_async_empty_roster_finishes_a_long_gap_without_changing_economy() -> void:
	var coins: int = world.player.wallet.balance
	var warehouse: Dictionary = world.storages.capture()
	var simulation: float = TimeManager.simulation_timestamp
	var progress: Array[float] = []
	var report: Callable = func(fraction: float) -> void: progress.append(fraction)
	service.catch_up_progress.connect(report)
	await service.advance_async(now + 365.0 * 86400.0, 1)
	service.catch_up_progress.disconnect(report)
	assert_eq(service.simulated_at, now + 365.0 * 86400.0)
	assert_eq(progress, [1.0])
	assert_eq(TimeManager.simulation_timestamp, simulation)
	assert_eq(world.player.wallet.balance, coins)
	assert_eq(world.storages.capture(), warehouse)
	assert_false(service.busy)

func test_offline_async_exact_finish_is_idempotent_and_restores_clock_scope() -> void:
	assert_eq(service.hire("orchard"), "")
	service.advance(now)
	var finish: float = float(service.record("orchard").task.finish_at)
	var processing: bool = TimeManager.is_processing()
	TimeManager.set_process(false)
	var simulation: float = TimeManager.simulation_timestamp
	await service.advance_async(finish, 1)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	var task: Dictionary = service.record("orchard").task.duplicate(true)
	await service.advance_async(finish, 1)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	assert_eq(service.record("orchard").task, task)
	assert_eq(TimeManager.simulation_timestamp, simulation)
	assert_false(service.busy)
	TimeManager.set_process(processing)

func test_offline_async_full_warehouse_crosses_dawn_without_losing_yield_or_double_wages() -> void:
	assert_eq(service.hire("orchard"), "")
	var warehouse: InventoryComponent = service.output_inventory()
	warehouse.add(APPLE, warehouse.capacity_for(APPLE) - 200)
	world.player.wallet.set_balance(0)
	var initial: int = warehouse.count_item(APPLE.item_id)
	var dawn: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	var processing: bool = TimeManager.is_processing()
	TimeManager.set_process(false)
	await service.advance_async(dawn + 60.0, 1000)
	assert_eq(warehouse.count_item(APPLE.item_id), initial, "A full batch must stay on its tree when storage cannot hold it")
	assert_true((world.trees.trees[Vector2i(12, 61)] as FruitTree).has_fruit())
	assert_false(service.record("orchard").active, "Insufficient wages pause the next shift")
	assert_eq(world.player.wallet.balance, 0)
	await service.advance_async(dawn + 60.0, 1)
	assert_eq(warehouse.count_item(APPLE.item_id), initial)
	assert_eq(world.player.wallet.balance, 0)
	assert_false(service.busy)
	TimeManager.set_process(processing)

class PickupEventBridge extends WorkerWorldBridge:
	var due: float = 0.0
	var emitted: bool = false
	var point: Vector2
	func sync(timestamp: float, offline: bool = true) -> void:
		super.sync(timestamp, offline)
		if not emitted and timestamp >= due:
			emitted = true
			var pile: ItemPickup = preload("res://scenes/objects/item_pickup.tscn").instantiate() as ItemPickup
			pile.item = APPLE
			pile.amount = 7
			pile.persistent_id = &"test_offline_event_pile"
			world.add_child(pile)
			pile.global_position = point

func test_pickup_event_uses_logical_time_for_every_async_budget() -> void:
	for tree: FruitTree in world.trees.trees.values():
		tree.fruit_work = 0.0
	assert_eq(service.hire("orchard"), "")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	var expected: Dictionary = {}
	var warehouse: Dictionary = {}
	var old_processing: bool = TimeManager.is_processing()
	TimeManager.set_process(false)
	for budget: int in [0, 1, 1000, 32000]:
		if not _restore_ok(adapter, checkpoint, now):
			break
		var probe: PickupEventBridge = PickupEventBridge.new(world)
		probe.due = now + 30.0
		probe.point = service.bridge.home("orchard") + Vector2(45, 30)
		service.bridge = probe
		if budget == 0:
			service.advance(now + 180.0)
			expected = service.capture(now + 180.0)
			warehouse = world.storages.capture()
		else:
			await service.advance_async(now + 180.0, budget)
			assert_eq(service.capture(now + 180.0), expected, "Pickup notifications must not depend on wall-clock chunk boundaries")
			assert_eq(world.storages.capture(), warehouse)
		assert_true(probe.emitted)
		assert_eq(service.output_inventory().count_item(APPLE.item_id), 7)
	TimeManager.set_process(old_processing)

func test_deferred_soil_edges_preserve_moisture_state_and_final_terrain() -> void:
	var farm: FarmingController = world.farming
	var soil: Array = [
		{"cell": [56, 22], "state": FarmingController.Soil.WET, "moisture": 10.0},
		{"cell": [56, 23], "state": FarmingController.Soil.WET, "moisture": 20.0},
		{"cell": [56, 24], "state": FarmingController.Soil.WET, "moisture": 30.0}]
	farm.restore_soil(soil)
	farm.evaporate_soil(15.0)
	var expected: Array[Dictionary] = farm.capture_soil()
	var tiles: Dictionary = {}
	for cell: Vector2i in farm.wet_soil.get_used_cells():
		tiles[cell] = farm.wet_soil.get_cell_atlas_coords(cell)
	farm.restore_soil(soil)
	farm.defer_soil_edges = true
	farm.evaporate_soil(15.0)
	assert_eq(farm.get_soil_state(Vector2i(56, 22)), FarmingController.Soil.DRY)
	assert_eq(farm.get_soil_state(Vector2i(56, 23)), FarmingController.Soil.WET)
	assert_eq(farm.capture_soil(), expected, "Only edge drawing may be deferred; moisture is committed at each event")
	farm.defer_soil_edges = false
	farm.flush_soil_edges()
	for cell: Vector2i in farm.wet_soil.get_used_cells():
		assert_eq(farm.wet_soil.get_cell_atlas_coords(cell), tiles[cell])

func test_restoring_offline_replays_trees_with_workers_before_advancing_gardens_to_now() -> void:
	assert_eq(service.hire("orchard"), "")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("worker_test", 1, now)
	var until: float = now + 18000.0
	service.advance(until)
	var expected: Dictionary = world.storages.capture()
	var workers: Dictionary = service.capture(until)
	var trees: Array = world.trees.capture(until)
	var old_processing: bool = TimeManager.is_processing()
	TimeManager.set_process(false)
	var restored: Dictionary = await adapter.restore_async(checkpoint, until)
	TimeManager.set_process(old_processing)
	assert_true(restored.ok, str(restored))
	assert_eq(world.storages.capture(), expected)
	assert_eq(service.capture(until), workers)
	assert_eq(world.trees.capture(until), trees)

func test_pollination_cache_rechecks_bloom_hive_moves_repairs_and_source_changes() -> void:
	var apiary: ApiarySystem = world.apiary
	apiary.begin_restore()
	apiary.loading = false
	var first: Beehive = apiary.create_hive(Vector2(5000, 5000), &"cache_a")
	var second: Beehive = apiary.create_hive(Vector2(5008, 5000), &"cache_b")
	var sources: Array[Dictionary] = [{"type": "sunflower", "name": "Sunflower", "point": Vector2(5001, 5000), "ready_at": now + 10.0}]
	apiary._assign(sources, now)
	assert_false(first.pollination.active())
	apiary._assign(sources, now + 10.0)
	assert_eq(first.pollination.source_id, "sunflower")
	assert_false(second.pollination.active())
	first.global_position += Vector2(1000, 0)
	apiary._assign(sources, now + 10.0)
	assert_false(first.pollination.active())
	assert_true(second.pollination.active())
	second.repaired = false
	apiary._assign(sources, now + 10.0)
	assert_false(second.pollination.active())
	second.repaired = true
	sources[0].point = first.global_position
	apiary._assign(sources, now + 10.0)
	assert_true(first.pollination.active())
	assert_false(second.pollination.active())

func test_flower_source_index_invalidates_on_restore_harvest_and_garden_lock() -> void:
	var apiary: ApiarySystem = world.apiary
	var farm: FarmingController = world.farming
	var cell: Vector2i = Vector2i(56, 22)
	var definition: CropDefinition = preload("res://crops/field/sunflower/sunflower.tres")
	var garden: FlowerGarden = apiary.gardens[0]
	garden.set_starter_content_locked(false)
	var before: int = apiary._flowers().size()
	farm.restore_crop(cell, definition, now - 1000.0, now - 1.0, 1.0, now)
	assert_eq(apiary._flowers().size(), before + 1)
	assert_true(farm.harvest(cell, service.output_inventory()))
	assert_eq(apiary._flowers().size(), before)
	garden.set_starter_content_locked(true)
	assert_true(apiary._flowers().all(func(source: Dictionary) -> bool: return not source.has("garden")))
	garden.set_starter_content_locked(false)
	assert_eq(apiary._flowers().size(), before)


func test_mature_timber_stump_still_crosses_offline_regrowth_boundary() -> void:
	var rules: TreeDefinition
	for definition: TreeDefinition in world.trees.definitions.values():
		if definition.kind == TreeDefinition.Kind.TIMBER:
			rules = definition
			break
	assert_not_null(rules)
	var tree: TimberTree = world.trees.create_tree(Vector2i(68, 61), rules, now) as TimberTree
	tree.growth_started_at = now - rules.growth_seconds - 1.0
	tree.matures_at = now - 1.0
	tree.last_at = now
	tree.stump = true
	tree.hits = rules.chop_hits
	tree.regrow_at = now + 10.0
	world.trees.advance(now + 11.0)
	assert_false(tree.stump, "A mature stump still has a pending regrowth event")
	assert_eq(tree.growth_started_at, now + 10.0)
	assert_eq(tree.matures_at, now + 10.0 + rules.growth_seconds * 0.5)
	assert_eq(tree.hits, 0)
	world.trees.advance(tree.matures_at + 1.0)
	assert_true(tree.is_mature())


func test_pickup_commit_skips_a_queued_old_instance_of_the_restored_id() -> void:
	var point: Vector2 = service.bridge.home("orchard") + Vector2(45, 30)
	var old: ItemPickup = ItemPickup.create()
	old.item = APPLE
	old.amount = 0
	old.persistent_id = &"restored_pickup_id"
	world.add_child(old)
	old.global_position = point
	old.queue_free()
	var fresh: ItemPickup = ItemPickup.create()
	fresh.item = APPLE
	fresh.amount = 7
	fresh.persistent_id = &"restored_pickup_id"
	world.add_child(fresh)
	fresh.global_position = point
	assert_true(service.bridge.commit({"role": "orchard", "zone": ""}, null, {"kind": "pickup", "id": "restored_pickup_id"}))
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 7)
	assert_eq(fresh.amount, 0)
