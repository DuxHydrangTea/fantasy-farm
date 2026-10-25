extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
var world: FarmWorld
var service: WorkerService
var now: float

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	service = world.workers
	now = world.farming.time_manager.now()
	var fixed_now: float = now
	world.farming.time_manager.clock_source = func() -> float: return fixed_now
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(1000000)
	world.trees.reset()
	for index: int in range(10):
		var tree: FruitTree = world.trees.create_tree(Vector2i(12 + index * 3, 61), world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1.0
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds if index == 0 else 0.0
		tree.refresh(now)
	await wait_process_frames(2)

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
	assert_true(SaveSchema.validate(saved, adapter.catalog).ok)
	assert_true(adapter.restore(saved, now + 20.0).ok)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	var second: Dictionary = adapter.capture("worker_test", 2, now + 20.0)
	assert_true(adapter.restore(second, now + 20.0).ok)
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
	var actor: WorkerActor = service.actors.orchard as WorkerActor
	var access: WorkerBoard = actor.get_node("ManagementSign") as WorkerBoard
	world.player.global_position = actor.global_position + Vector2(0, 20)
	assert_true(access.open_shop(world.player))
	assert_true((access.menu as WorkerMenu).collect_button.visible)

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
	service.advance(now + 172800.0)
	var single: Dictionary = service.capture(now + 172800.0)
	var warehouse: Dictionary = world.storages.capture()
	var coins: int = world.player.wallet.balance
	assert_true(adapter.restore(checkpoint, now).ok)
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
	assert_true(adapter.preflight(saved).ok)
	assert_true(adapter.restore(saved, now).ok)
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
	assert_true(SaveSchema.validate(checkpoint, adapter.catalog).ok)
	service.advance(now + 7200.0)
	var single: Dictionary = service.capture(now + 7200.0)
	var warehouse: Dictionary = world.storages.capture()
	var stock: float = food.available_units()
	assert_true(adapter.restore(checkpoint, now).ok)
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
	service.advance(now + 120)
	var single: Dictionary = service.capture(now + 120)
	var warehouse: Dictionary = world.storages.capture()
	assert_true(adapter.restore(checkpoint, now).ok)
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
