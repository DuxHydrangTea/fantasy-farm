extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const NOW: float = 1793155000.0
var world: FarmWorld
var team: WorkerService
var source: InventoryComponent
var cells: Array[Vector2i]
var old_clock: Callable
var old_floor: float

func before_each() -> void:
	old_clock = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	TimeManager._last_timestamp = NOW
	TimeManager.clock_source = func() -> float: return NOW
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_blocks(12, 4)
	world.player.wallet.set_balance(2000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	team = world.workers
	source = team.feed_inventory("crop")
	cells = WorkerAreaPolicy.footprint(Vector2i(54, 30), 3)
	world.farming.restore_soil([])
	for cell: Vector2i in world.farming.farmland.get_used_cells():
		if LandExpansionState.REGION.has_point(cell):
			world.farming.set_cell_occupied(cell, not cells.has(cell))
	for pen: AnimalPen in team.bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				(child as AnimalTrough).stock = (child as AnimalTrough).capacity
	world.farming.crop_planted.connect(func(_cell: Vector2i, crop: Crop) -> void:
		crop.conditions.pest_roll = 1.0
		crop.conditions.weed_roll = 1.0
		crop.conditions.yield_roll = 0.5)

func after_each() -> void:
	TimeManager.clock_source = old_clock
	TimeManager._last_timestamp = old_floor

func hire() -> Dictionary:
	assert_eq(team.hire("crop"), "")
	var row: Dictionary = team.records.back()
	var actor: WorkerActor = team.actor_for(row.id)
	actor.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cells[0]))
	row.position = WorkerRole.pair(actor.global_position)
	return row

func test_team_limit_purchase_atomicity_and_rehire_keeps_progress() -> void:
	for index: int in range(3):
		hire()
	assert_ne(team.hire("crop"), "")
	assert_eq(team.actors.size(), 3)
	var balance: int = world.player.wallet.balance
	var observed: Array = []
	team.upgrade_shop.purchased.connect(func(_track: String, _level: int, _price: int) -> void:
		observed.append(team.upgrades.level("speed"))
		observed.append(team.upgrade_shop.purchase("speed", 1, 15000).ok))
	assert_true(team.upgrade_shop.purchase("speed", 0, 10000).ok)
	assert_eq(observed, [1, false])
	assert_eq(world.player.wallet.balance, balance - 10000)
	assert_false(team.upgrade_shop.purchase("speed", 0, 10000).ok)
	assert_eq(world.player.wallet.balance, balance - 10000)
	for row: Dictionary in team.records:
		assert_eq(team.dismiss(row.id), "")
	assert_eq(team.upgrades.level("speed"), 1)
	assert_eq(team.hire("crop"), "")
	assert_eq(team.upgrades.level("speed"), 1)

func test_duration_snapshot_survives_purchase_arrival_and_reload() -> void:
	var row: Dictionary = hire()
	source.add(SEED, 9)
	team.advance(NOW)
	var task: Dictionary = row.task.duplicate(true)
	assert_eq(float(task.duration), 2.0)
	assert_true(team.upgrade_shop.purchase("speed", 0, 10000).ok)
	assert_eq(row.task.duration, task.duration)
	assert_eq(row.task.finish_at, task.finish_at)
	var actor: WorkerActor = team.actor_for(row.id)
	actor.global_position = WorkerRole.point(row.task.point)
	row.task.erase("arrived_at")
	actor.behaviour._physics_process(0.01)
	assert_almost_eq(float(row.task.finish_at) - float(row.task.work_at), 2.0, 0.001)
	team.upgrades.levels.speed = 10
	assert_almost_eq(team.upgrades.duration(2.0, "harvest"), 0.69735688, 0.000001)
	assert_eq(team.upgrades.duration(2.0, "patrol"), 2.0)
	var saved: Dictionary = team.capture(NOW)
	assert_true(WorkerSaveSchema.valid(saved, SaveCatalog.new(), NOW))
	team.restore(saved, SaveCatalog.new())
	assert_eq(team.upgrades.level("speed"), 10)
	assert_eq(team.records[0].task.duration, task.duration)

func test_insufficient_funds_max_level_and_player_tools_are_independent() -> void:
	var tools: Dictionary = world.tool_upgrades.state.capture()
	world.player.wallet.set_balance(9999)
	assert_false(team.upgrade_shop.purchase("speed", 0, 10000).ok)
	assert_eq(team.upgrades.level("speed"), 0)
	world.player.wallet.set_balance(2000000)
	for level: int in range(10):
		assert_true(team.upgrade_shop.purchase("speed", level, WorkerUpgradeService.CATALOG.price("speed", level)).ok)
	assert_false(team.upgrade_shop.quote("speed").ok)
	assert_true(team.upgrade_shop.purchase("hoe", 1, 30000).ok)
	assert_true(team.upgrade_shop.purchase("hoe", 2, 90000).ok)
	assert_false(team.upgrade_shop.quote("hoe").ok)
	assert_eq(world.tool_upgrades.state.capture(), tools)

func test_three_by_three_till_plant_and_partial_save_replay() -> void:
	hire()
	team.upgrades.levels.hoe = 3
	team.upgrades.levels.sowing = 3
	team.upgrades.levels.speed = 10
	source.add(SEED, 9)
	team.advance(NOW)
	var row: Dictionary = team.records[0]
	assert_eq(row.task.kind, "till")
	assert_eq(row.task.cells.size(), 9)
	var finish: float = row.task.finish_at
	team.advance(finish)
	assert_eq(int(row.task.cursor), 1, "Only one cell committed at this event endpoint")
	assert_eq(team.crop_automation.prepared_cells(row.id).size(), 1)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("upgrade_test", 1, finish)
	assert_true(SaveSchema.validate(saved, adapter.catalog).ok)
	team.advance(NOW + 30)
	assert_eq(world.farming.crop_cells().size(), 9)
	assert_eq(team.crop_automation.sequence, 9)
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_true(adapter.restore(saved, finish).ok)
	team.advance(NOW + 30)
	assert_eq(world.farming.crop_cells().size(), 9)
	assert_eq(team.crop_automation.sequence, 9)
	assert_eq(team.feed_inventory("crop").count_item(SEED.item_id), 0)

func test_batch_reserves_last_seeds_and_rechecks_removed_supplies() -> void:
	var first: Dictionary = hire()
	hire()
	hire()
	team.upgrades.levels.hoe = 3
	source.add(SEED, 5)
	team.advance(NOW)
	assert_eq(first.task.cells.size(), 5)
	assert_eq(team.reserved_items(String(SEED.item_id)), 5)
	var held: Dictionary = team.reservations("")
	assert_eq(held.items[String(SEED.item_id)], 5)
	assert_eq(team.records[1].task.kind, "patrol")
	source.remove(SEED.item_id, 5)
	team.advance(NOW + 30)
	assert_eq(team.crop_automation.sequence, 0)
	assert_true(world.farming.crop_cells().is_empty())

func test_batch_harvest_keeps_care_affected_and_unaccepted_crops() -> void:
	var row: Dictionary = hire()
	team.configure_crop(false, false, false)
	team.upgrades.levels.harvest = 3
	var soil: Array = []
	for cell: Vector2i in cells:
		soil.append({"cell": [cell.x, cell.y], "state": 1})
	world.farming.restore_soil(soil)
	for cell: Vector2i in cells:
		world.farming.restore_crop(cell, SEED.crop, NOW - 100, NOW - 1, 1.0, NOW)
		var crop: Crop = world.farming.get_crop(cell)
		crop.conditions.pests = false
		crop.conditions.weeds = false
		crop.conditions.yield_roll = 0.5
	var protected: Vector2i = cells.back()
	world.farming.get_crop(protected).conditions.pests = true
	var task: Dictionary = team.crop_policy.task("harvest", cells[0], 0)
	WorkerAreaPolicy.expand(team, row, task)
	assert_eq(task.cells.size(), 8)
	# Fill warehouse after assignment; no plant may be destroyed.
	var output: InventoryComponent = team.output_inventory()
	for i: int in range(output.slot_count):
		output.add(SEED.crop.harvest_item, output.stack_limit_for(SEED.crop.harvest_item))
	team.busy = true
	while int(task.cursor) < task.cells.size():
		WorkerAreaPolicy.commit_next(team, row, task)
	team.busy = false
	assert_eq(world.farming.crop_cells().size(), 9)
	assert_not_null(world.farming.get_crop(protected))

func test_legacy_fifteen_migrates_without_actors_or_product_loss() -> void:
	var row: Dictionary = hire()
	team.configure_crop(false, false, true)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var old: Dictionary = adapter.capture("upgrade_test", 1, NOW)
	old.version = 40
	old.workers.erase("upgrades")
	old.workers.erase("legacy_baskets")
	old.workers.rows.clear()
	old.workers.next_order = 16
	var seed_row: Dictionary = team.capture(NOW).rows[0]
	for index: int in range(15):
		var copy: Dictionary = seed_row.duplicate(true)
		copy.id = "legacy_%d" % index
		copy.slot = index + 1
		copy.hire_order = index + 1
		copy.task = {}
		if index >= 3:
			copy.basket[0] = {"item": String(SEED.crop.harvest_item.item_id), "count": 1, "tiers": [1, 0, 0]}
		old.workers.rows.append(copy)
	var checked: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(checked.ok, str(checked.get("error", "")))
	assert_eq(old.workers.rows.size(), 15, "Migration must not mutate input")
	assert_eq(checked.snapshot.workers.rows.size(), 3)
	assert_eq(checked.snapshot.workers.legacy_baskets.size(), 12)
	assert_true(adapter.restore(old, NOW).ok)
	assert_eq(team.actors.size(), 3)
	assert_eq(team.output_inventory().count_item(SEED.crop.harvest_item.item_id), 12)
	assert_true(team.legacy_baskets.is_empty())
	var full: Dictionary = checked.snapshot.duplicate(true)
	full.storages.produce_warehouse = {"slot_count": 1, "stack_cap": 12, "slots": [{"item": String(SEED.crop.harvest_item.item_id), "count": 12, "tiers": [12, 0, 0]}]}
	assert_true(adapter.restore(full, NOW).ok)
	assert_eq(team.legacy_baskets.size(), 12, "Full warehouse must preserve archived produce")
	assert_true(SaveSchema.validate(adapter.capture("upgrade_test", 2, NOW), adapter.catalog).ok)
	team.output_inventory().remove(SEED.crop.harvest_item.item_id, 12)
	team.advance(NOW)
	assert_eq(team.output_inventory().count_item(SEED.crop.harvest_item.item_id), 12)
	assert_true(team.legacy_baskets.is_empty())

func test_batch_watering_and_harvest_commit_real_cells_once() -> void:
	var row: Dictionary = hire()
	team.configure_crop(false, false, false)
	team.upgrades.levels.watering = 3
	team.upgrades.levels.harvest = 3
	var soil: Array = []
	for cell: Vector2i in cells:
		soil.append({"cell": [cell.x, cell.y], "state": 1})
	world.farming.restore_soil(soil)
	for cell: Vector2i in cells:
		world.farming.restore_crop(cell, SEED.crop, NOW, NOW + 10000, 0.0, NOW)
	var water: Dictionary = team.crop_policy.task("water_crop", cells[0], 1)
	WorkerAreaPolicy.expand(team, row, water)
	assert_eq(water.cells.size(), 9)
	team.busy = true
	while int(water.cursor) < water.cells.size():
		WorkerAreaPolicy.commit_next(team, row, water)
	team.busy = false
	for cell: Vector2i in cells:
		assert_false(world.farming.can_water(cell))
	for cell: Vector2i in cells:
		world.farming.get_crop(cell).restore_progress(SEED.crop, NOW - 100, NOW - 1, 1.0, NOW)
		world.farming.get_crop(cell).conditions.pests = false
		world.farming.get_crop(cell).conditions.weeds = false
		world.farming.get_crop(cell).conditions.yield_roll = 0.5
	var harvest: Dictionary = team.crop_policy.task("harvest", cells[0], 0)
	WorkerAreaPolicy.expand(team, row, harvest)
	assert_eq(harvest.cells.size(), 9)
	var expected: int = 0
	for cell: Vector2i in cells:
		expected += world.farming.harvest_amount(cell)
	team.busy = true
	while int(harvest.cursor) < harvest.cells.size():
		WorkerAreaPolicy.commit_next(team, row, harvest)
	team.busy = false
	assert_true(world.farming.crop_cells().is_empty())
	assert_eq(team.output_inventory().count_item(SEED.crop.harvest_item.item_id), expected)

func test_schema_rejects_invalid_upgrade_and_batch_state() -> void:
	hire()
	team.upgrades.levels.hoe = 3
	source.add(SEED, 9)
	team.advance(NOW)
	var saved: Dictionary = team.capture(NOW)
	var catalog: SaveCatalog = SaveCatalog.new()
	assert_true(WorkerSaveSchema.valid(saved, catalog, NOW))
	for value: Variant in [-1, 11, NAN, 1.5, "1"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.upgrades.speed = value
		assert_false(WorkerSaveSchema.valid(bad, catalog, NOW))
	for value: Variant in [-1, 9, 0.5, "0"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.rows[0].task.cursor = value
		assert_false(WorkerSaveSchema.valid(bad, catalog, NOW))
	var overlap: Dictionary = saved.duplicate(true)
	overlap.rows[0].task.cells[1] = overlap.rows[0].task.cells[0]
	assert_false(WorkerSaveSchema.valid(overlap, catalog, NOW))

func test_two_by_two_footprint_and_resume_checks_every_reserved_cell() -> void:
	var first: Dictionary = hire()
	var second: Dictionary = hire()
	team.upgrades.levels.hoe = 2
	source.add(SEED, 8)
	var task: Dictionary = team.crop_policy.task("till", cells[0], 5, SEED)
	WorkerAreaPolicy.expand(team, first, task)
	assert_eq(task.cells.size(), 4)
	first.task = task
	first.active = false
	var extra: Array = task.cells[1]
	second.task = team.crop_policy.task("till", Vector2i(extra[0], extra[1]), 5, SEED)
	first.active = true
	assert_false(team.target_available(first, first.task), "Conflicting non-anchor cells must stop resumed work")
	var shared: Vector2i = Vector2i(extra[0], extra[1])
	team.crop_automation.add_prepared(first.id, shared)
	team.crop_automation.add_prepared(second.id, shared)
	team._resume_task(first, NOW)
	assert_true(first.task.is_empty())
	assert_true(team.crop_automation.prepared_cells(first.id).is_empty())
	assert_eq(team.crop_automation.prepared_cells(second.id), [shared], "Resuming a worker must preserve its colleague's preparation")

func test_upgraded_three_worker_offline_jump_matches_segmented_replay() -> void:
	for index: int in range(3):
		hire()
	team.upgrades.levels = {"speed": 10, "hoe": 3, "sowing": 3, "watering": 3, "harvest": 3}
	source.add(SEED, 18)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var initial: Dictionary = adapter.capture("upgrade_test", 1, NOW)
	team.advance(NOW + 3600)
	var one: Dictionary = adapter.capture("upgrade_test", 2, NOW + 3600)
	assert_true(adapter.restore(initial, NOW).ok)
	for minute: int in range(1, 61):
		team.advance(NOW + minute * 60)
	var stepped: Dictionary = adapter.capture("upgrade_test", 2, NOW + 3600)
	assert_eq(stepped.storages, one.storages)
	assert_eq(stepped.crops, one.crops)
	assert_eq(stepped.coins, one.coins)
	assert_eq(stepped.workers.crop_automation, one.workers.crop_automation)
	assert_eq(team.crop_automation.sequence, 18)
	assert_true(SaveSchema.validate(stepped, adapter.catalog).ok)

func test_batch_does_not_reach_through_a_wall_or_locked_plot() -> void:
	var row: Dictionary = hire()
	team.upgrades.levels.hoe = 3
	source.add(SEED, 9)
	var point: Vector2 = WorkerRole.point(row.position)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = world.farming.obstacle_mask
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(2, 80)
	collision.shape = shape
	wall.add_child(collision)
	add_child_autofree(wall)
	wall.global_position = point + Vector2(8, 0)
	await wait_physics_frames(2)
	var task: Dictionary = team.crop_policy.task("till", cells[0], 5, SEED)
	WorkerAreaPolicy.expand(team, row, task)
	for pair: Array in task.cells:
		assert_lte(int(pair[0]), cells[0].x, "Cells behind the wall are outside the reachable batch")
	assert_false(WorkerAreaPolicy.eligible(team, row, task, Vector2i(10, 20)), "Unowned land cannot be farmed")

func test_max_speed_completes_online_only_after_actual_arrival_and_work() -> void:
	var row: Dictionary = hire()
	for level: int in [0, 1, 5, 10]:
		team.upgrades.levels.speed = level
		assert_almost_eq(team.upgrades.duration(2.0, "harvest"), 2.0 * pow(0.9, level), 0.000001)
	team.upgrades.levels.speed = 10
	source.add(SEED, 1)
	team.advance(NOW)
	var actor: WorkerActor = team.actor_for(row.id)
	actor.global_position = WorkerRole.point(row.task.point)
	var arrived: float = NOW + 10.0
	TimeManager.clock_source = func() -> float: return arrived
	actor.behaviour._physics_process(0.01)
	assert_almost_eq(float(row.task.work_at), arrived, 0.001)
	assert_almost_eq(float(row.task.finish_at) - arrived, 0.69735688, 0.00001)
	var cell: Vector2i = Vector2i(row.task.cell[0], row.task.cell[1])
	team.advance(arrived + 0.68, false)
	assert_eq(world.farming.get_soil_state(cell), FarmingController.Soil.UNTILLED)
	team.advance(arrived + 0.70, false)
	assert_eq(world.farming.get_soil_state(cell), FarmingController.Soil.DRY)

func test_commit_rechecks_actual_position_reservation_and_player_changes() -> void:
	var row: Dictionary = hire()
	var second: Dictionary = hire()
	team.upgrades.levels.hoe = 3
	source.add(SEED, 9)
	var task: Dictionary = team.crop_policy.task("till", cells[0], 5, SEED)
	WorkerAreaPolicy.expand(team, row, task)
	var actor: WorkerActor = team.actor_for(row.id)
	actor.global_position += Vector2(100, 0)
	team.busy = true
	WorkerAreaPolicy.commit_next(team, row, task)
	assert_eq(world.farming.get_soil_state(cells[0]), FarmingController.Soil.UNTILLED, "A displaced worker cannot commit remotely")
	actor.global_position = WorkerRole.point(task.point)
	var claimed: Vector2i = WorkerAreaPolicy.task_cells(task)[0]
	second.task = team.crop_policy.task("till", claimed, 5, SEED)
	WorkerAreaPolicy.commit_next(team, row, task)
	assert_eq(world.farming.get_soil_state(claimed), FarmingController.Soil.UNTILLED, "New conflicting reservations are rechecked")
	second.task = {}
	var occupied: Vector2i = WorkerAreaPolicy.task_cells(task)[0]
	world.farming.set_cell_occupied(occupied, true)
	WorkerAreaPolicy.commit_next(team, row, task)
	assert_eq(world.farming.get_soil_state(occupied), FarmingController.Soil.UNTILLED)
	row.active = false
	var paused: Vector2i = WorkerAreaPolicy.task_cells(task)[0]
	WorkerAreaPolicy.commit_next(team, row, task)
	assert_eq(world.farming.get_soil_state(paused), FarmingController.Soil.UNTILLED)
	team.busy = false

func test_every_partial_plant_cursor_restores_without_double_spending() -> void:
	var row: Dictionary = hire()
	team.upgrades.levels.sowing = 3
	team.upgrades.levels.speed = 10
	var soil: Array = []
	for cell: Vector2i in cells:
		soil.append({"cell": [cell.x, cell.y], "state": 1})
	world.farming.restore_soil(soil)
	source.add(SEED, 9)
	team.advance(NOW)
	assert_eq(row.task.kind, "plant")
	assert_eq(row.task.cells.size(), 9)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var initial: Dictionary = adapter.capture("upgrade_test", 1, NOW)
	for cursor: int in range(1, 9):
		assert_true(adapter.restore(initial, NOW).ok)
		row = team.records[0]
		var endpoint: float = float(row.task.finish_at) + (cursor - 1) * 0.00001
		team.advance(endpoint)
		assert_eq(int(row.task.cursor), cursor)
		var checkpoint: Dictionary = adapter.capture("upgrade_test", 2, endpoint)
		assert_true(SaveSchema.validate(checkpoint, adapter.catalog).ok)
		assert_true(adapter.restore(checkpoint, endpoint).ok)
		team.advance(NOW + 30)
		assert_eq(world.farming.crop_cells().size(), 9)
		assert_eq(team.crop_automation.sequence, 9)
		assert_eq(team.feed_inventory("crop").count_item(SEED.item_id), 0)

func test_player_blocked_prepared_batch_does_not_stall_other_empty_plots() -> void:
	var row: Dictionary = hire()
	source.add(SEED, 9)
	var soil: Array = []
	for index: int in range(3):
		var cell: Vector2i = cells[index]
		soil.append({"cell": [cell.x, cell.y], "state": 1})
		team.crop_automation.add_prepared(row.id, cell)
		world.farming.set_cell_occupied(cell, true)
	world.farming.restore_soil(soil)
	team.crop_policy.invalidate()
	var chosen: Dictionary = team.crop_policy.planting_task(row)
	assert_true(team.crop_automation.prepared_cells(row.id).is_empty())
	assert_false(chosen.is_empty(), "Invalid prepared cells must release the worker to till another plot immediately")
	assert_eq(chosen.get("kind", ""), "till")
