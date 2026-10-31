extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
const FIXED_TIME: float = 1793155000.0
var world: FarmWorld
var service: WorkerService
var source: InventoryComponent
var clock: Array[float] = []
var old_clock: Callable
var old_floor: float
var cells: Array[Vector2i] = []

func before_each() -> void:
	old_clock = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	clock = [FIXED_TIME]
	var manual: Array[float] = clock
	TimeManager._last_timestamp = FIXED_TIME
	TimeManager.clock_source = func() -> float: return manual[0]
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(1000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.farming.restore_soil([])
	service = world.workers
	source = world.storages.inventory("farm_supply_storage")
	# The unified worker services troughs at higher priority than planting;
	# these tests are about crop work, so keep every trough full.
	for pen: AnimalPen in service.bridge.pens():
		for node: Node in pen.get_children():
			if node is AnimalTrough:
				(node as AnimalTrough).stock = (node as AnimalTrough).capacity
	cells.clear()
	for index: int in range(5):
		cells.append(Vector2i(48 + index, 30))
	# Occupancy survives adapter restore, so replay tests use the same five plots.
	for y: int in range(LandExpansionState.REGION.position.y, LandExpansionState.REGION.end.y):
		for x: int in range(LandExpansionState.REGION.position.x, LandExpansionState.REGION.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not cell in cells:
				world.farming.set_cell_occupied(cell, true)

func after_each() -> void:
	TimeManager.clock_source = old_clock
	TimeManager._last_timestamp = old_floor

func _hire(count: int = 5) -> void:
	for index: int in range(count):
		assert_eq(service.hire("crop"), "")
	for row: Dictionary in service.records_for("crop"):
		var actor: WorkerActor = service.actor_for(row.id)
		actor.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cells[(int(row.slot) - 1) % cells.size()] + Vector2i.UP))
		row.position = WorkerRole.pair(actor.global_position)

func _assert_distinct_work(expected: int) -> void:
	var targets: Dictionary = {}
	var count: int = 0
	for row: Dictionary in service.records_for("crop", true):
		if row.task.is_empty() or row.task.kind == "patrol":
			continue
		var key: String = service.target_key(row.task)
		assert_false(targets.has(key), "Each plot/pickup belongs to one worker")
		targets[key] = true
		count += 1
	assert_eq(count, expected)

func test_cap_per_worker_wages_rehire_and_bounded_records() -> void:
	_hire(15)
	assert_eq(world.player.wallet.balance, 1000000 - 14 * 2800)
	assert_ne(service.hire("crop"), "")
	var rows: Array[Dictionary] = service.records_for("crop")
	var chosen: Dictionary = rows[2]
	var kept_id: String = chosen.id
	var number: int = service.worker_number(kept_id)
	for attempt: int in range(8):
		assert_eq(service.dismiss(kept_id), "")
		assert_false(chosen.employed)
		assert_true(rows[0].employed)
		assert_eq(service.hire("crop"), "")
		assert_eq(service.records_for("crop").size(), 15)
		assert_true(chosen.employed)
		assert_eq(service.worker_number(kept_id), number)
	assert_eq(world.player.wallet.balance, 1000000 - 22 * 2800)
	assert_eq(service.actors.size(), 15)

func test_all_five_receive_distinct_till_jobs_and_finish_planting() -> void:
	_hire()
	source.add(SEED, 5)
	service.advance(FIXED_TIME)
	_assert_distinct_work(5)
	for row: Dictionary in service.records_for("crop"):
		assert_eq(row.task.kind, "till")
	service.advance(FIXED_TIME + 35)
	assert_eq(service.crop_automation.sequence, 5)
	assert_eq(world.farming.crop_cells().size(), 5)
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_true(service.crop_automation.prepared.is_empty())

func test_last_seed_is_reserved_and_other_seed_is_still_available() -> void:
	_hire()
	source.add(SEED, 1)
	source.add(OTHER, 1)
	service.advance(FIXED_TIME)
	_assert_distinct_work(2)
	assert_eq(service.reserved_items(String(SEED.item_id)), 1)
	assert_eq(service.reserved_items(String(OTHER.item_id)), 1)
	service.advance(FIXED_TIME + 40)
	assert_eq(service.crop_automation.sequence, 2)
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_eq(source.count_item(OTHER.item_id), 0)

func test_dismissal_and_team_toggle_release_assignments_and_wake_everyone() -> void:
	_hire()
	source.add(SEED, 5)
	service.advance(FIXED_TIME)
	var row: Dictionary = service.records_for("crop")[2]
	assert_eq(service.dismiss(row.id), "")
	assert_eq(service.reserved_items(String(SEED.item_id)), 4)
	assert_eq(service.configure_crop(false, false, false), "")
	for worker: Dictionary in service.records_for("crop"):
		assert_true(worker.task.is_empty())
	assert_eq(service.reserved_items(String(SEED.item_id)), 0)
	assert_eq(service.configure_crop(true, true, false), "")
	service.advance(FIXED_TIME)
	_assert_distinct_work(4)
	var finishes: Dictionary = {}
	for worker: Dictionary in service.records_for("crop", true):
		finishes[worker.id] = worker.task.finish_at
	service.configure_crop(true, true, true)
	assert_eq(service.reserved_items(String(SEED.item_id)), 0)
	service.advance(FIXED_TIME + 100)
	clock[0] += 100
	service.configure_crop(true, true, false)
	for worker: Dictionary in service.records_for("crop", true):
		assert_almost_eq(float(worker.task.finish_at), float(finishes[worker.id]) + 100, 0.001)

func test_prepared_plots_are_independent_and_save_roundtrip_preserves_each_worker() -> void:
	_hire()
	source.add(SEED, 5)
	service.busy = true
	for index: int in range(5):
		var row: Dictionary = service.records_for("crop")[index]
		assert_true(service.crop_policy.commit(row, service.crop_policy.task("till", cells[index], 5, SEED)))
	service.busy = false
	assert_eq(service.crop_automation.prepared.size(), 5)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	assert_true(SaveSchema.validate(saved, adapter.catalog).ok)
	var ids: Array = service.actors.keys()
	assert_true(adapter.restore(saved, FIXED_TIME).ok)
	assert_eq(service.actors.keys(), ids)
	assert_eq(service.crop_automation.prepared.size(), 5)
	for row: Dictionary in service.records_for("crop"):
		assert_eq(service.crop_policy.planting_task(row).cell, [cells[int(row.slot) - 1].x, 30])
	service.advance(FIXED_TIME + 30)
	assert_eq(service.crop_automation.sequence, 5)

func test_v35_migration_keeps_id_prepared_plot_and_trial_without_mutating_input() -> void:
	_hire(1)
	source.add(SEED, 1)
	var row: Dictionary = service.record("crop")
	service.busy = true
	assert_true(service.crop_policy.commit(row, service.crop_policy.task("till", cells[0], 5, SEED)))
	service.busy = false
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var legacy: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	legacy.version = 35
	legacy.workers.rows[0].erase("slot")
	legacy.workers.crop_automation.prepared = [cells[0].x, cells[0].y]
	var checked: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(checked.ok, str(checked))
	assert_eq(legacy.version, 35)
	assert_eq(legacy.workers.crop_automation.prepared, [48, 30])
	assert_true(adapter.restore(legacy, FIXED_TIME).ok)
	assert_eq(service.record("crop").id, row.id)
	assert_eq(service.crop_automation.prepared_for(row.id), cells[0])
	assert_eq(service.records_for("crop").size(), 1)
	var balance: int = world.player.wallet.balance
	assert_eq(service.hire("crop"), "")
	assert_eq(world.player.wallet.balance, balance - 2800)

func test_insufficient_wages_pause_only_unpaid_workers_and_still_occupy_slots() -> void:
	_hire(15)
	service.configure_crop(false, false, true)
	world.player.wallet.set_balance(2 * 2800)
	var dawn: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(FIXED_TIME) + 1)
	service.advance(dawn)
	var rows: Array[Dictionary] = service.records_for("crop")
	for index: int in range(15):
		assert_eq(bool(rows[index].active), index < 2)
	assert_eq(world.player.wallet.balance, 0)
	world.player.wallet.set_balance(100000)
	clock[0] = dawn
	assert_ne(service.hire("crop"), "")
	service.advance(dawn)
	assert_eq(world.player.wallet.balance, 100000, "No repeated payroll at the same dawn")

func test_offline_long_jump_matches_segmented_and_reload_preserves_slot_numbers() -> void:
	_hire()
	source.add(SEED, 10)
	source.add(FERTILIZER, 10)
	service.configure_crop(true, true, false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var initial: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	service.advance(FIXED_TIME + 172800)
	var single: Dictionary = adapter.capture("crop_team_test", 2, FIXED_TIME + 172800)
	assert_true(adapter.restore(initial, FIXED_TIME).ok)
	for hour: int in range(1, 49):
		service.advance(FIXED_TIME + hour * 3600)
	var stepped: Dictionary = adapter.capture("crop_team_test", 2, FIXED_TIME + 172800)
	assert_eq(stepped.workers, single.workers)
	assert_eq(stepped.storages, single.storages)
	assert_eq(stepped.crops, single.crops)
	assert_eq(stepped.coins, single.coins)
	assert_eq(service.crop_automation.sequence, 10)
	assert_true(SaveSchema.validate(stepped, adapter.catalog).ok)

func test_removed_supplies_and_player_work_do_not_duplicate_or_spend_extra_stock() -> void:
	_hire()
	source.add(SEED, 5)
	service.advance(FIXED_TIME)
	source.remove(SEED.item_id, 5)
	service.advance(FIXED_TIME + 20)
	assert_eq(service.crop_automation.sequence, 0)
	assert_eq(world.farming.crop_cells().size(), 0)
	source.add(SEED, 5)
	service.advance(FIXED_TIME + 60)
	assert_eq(service.crop_automation.sequence, 5)
	assert_eq(source.count_item(SEED.item_id), 0)

func test_schema_rejects_six_workers_duplicate_ids_slots_and_invalid_prepared_owners() -> void:
	_hire()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	for key: String in ["id", "slot", "hire_order"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.workers.rows[1][key] = bad.workers.rows[0][key]
		assert_false(SaveSchema.validate(bad, adapter.catalog).ok)
	var sixth: Dictionary = saved.duplicate(true)
	sixth.workers.rows.append(sixth.workers.rows[0].duplicate(true))
	assert_false(SaveSchema.validate(sixth, adapter.catalog).ok)
	var invalid_owner: Dictionary = saved.duplicate(true)
	invalid_owner.workers.crop_automation.prepared = [{"worker": "missing_worker", "cell": [48, 30]}]
	assert_false(SaveSchema.validate(invalid_owner, adapter.catalog).ok)

func test_only_one_worker_takes_last_fertilizer_and_each_crop_is_fertilized_once() -> void:
	_hire()
	source.add(SEED, 5)
	service.busy = true
	for index: int in range(5):
		var row: Dictionary = service.records_for("crop")[index]
		assert_true(service.crop_policy.commit(row, service.crop_policy.task("till", cells[index], 5, SEED)))
		assert_true(service.crop_policy.commit(row, service.crop_policy.task("plant", cells[index], 4, SEED)))
		assert_true(world.farming.water(cells[index]))
	service.busy = false
	source.add(FERTILIZER, 1)
	service.configure_crop(false, true, false)
	service.advance(FIXED_TIME)
	_assert_distinct_work(1)
	assert_eq(service.reserved_items(String(FERTILIZER.item_id)), 1)
	service.advance(FIXED_TIME + 15)
	var fertilized: int = 0
	for cell: Vector2i in cells:
		fertilized += 1 if world.farming.get_crop(cell).fertilized else 0
	assert_eq(fertilized, 1)
	assert_eq(source.count_item(FERTILIZER.item_id), 0)

func test_player_replacing_a_claimed_plot_and_full_warehouse_preserve_yield() -> void:
	_hire()
	source.add(SEED, 5)
	service.advance(FIXED_TIME)
	var row: Dictionary = service.records_for("crop")[0]
	var cell: Vector2i = Vector2i(int(row.task.cell[0]), int(row.task.cell[1]))
	assert_true(world.farming.till(cell))
	assert_eq(world.farming.apply_area(&"plant", [cell], source, -1, SEED, world.player, true).changed, 1)
	service.advance(FIXED_TIME + 35)
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_eq(world.farming.crop_cells().size(), 5)
	assert_eq(service.crop_automation.sequence, 4, "The player's crop is not counted as a worker planting")
	var crop: Crop = world.farming.get_crop(cell)
	crop.progress = 1.0
	var item: ItemDefinition = (SEED.crop as CropDefinition).harvest_item
	var warehouse: InventoryComponent = service.output_inventory()
	warehouse.add(item, warehouse.capacity_for(item))
	var before: int = warehouse.count_item(item.item_id)
	service.advance(FIXED_TIME + 60)
	assert_not_null(world.farming.get_crop(cell))
	assert_eq(warehouse.count_item(item.item_id), before)

func test_active_duplicate_assignments_are_rejected_and_stuck_worker_does_not_block_team() -> void:
	_hire()
	source.add(SEED, 5)
	service.advance(FIXED_TIME)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	saved.workers.rows[1].task = saved.workers.rows[0].task.duplicate(true)
	assert_false(SaveSchema.validate(saved, adapter.catalog).ok)
	var first: Dictionary = service.records_for("crop")[0]
	var second: Dictionary = service.records_for("crop")[1]
	var old_job: Dictionary = first.task.duplicate(true)
	first.task.attempt = 4
	service.blocked(first.id, FIXED_TIME)
	assert_true(first.task.is_empty())
	assert_true(service.target_available(second, old_job))
	assert_false(service.blocked_targets.has(second.id + ":" + String(old_job.id)))

func test_five_worker_online_events_match_offline_when_arrivals_are_unobstructed() -> void:
	_hire()
	source.add(SEED, 5)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var initial: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	service.advance(FIXED_TIME + 35)
	var expected: Dictionary = adapter.capture("crop_team_test", 2, FIXED_TIME + 35)
	assert_true(adapter.restore(initial, FIXED_TIME).ok)
	for index: int in range(1, 141):
		var timestamp: float = FIXED_TIME + float(index) * 0.25
		for row: Dictionary in service.records_for("crop"):
			if not row.task.is_empty() and float(row.task.finish_at) <= timestamp:
				service.actor_for(row.id).global_position = WorkerRole.point(row.task.point)
		service.advance(timestamp, false)
	var online: Dictionary = adapter.capture("crop_team_test", 2, FIXED_TIME + 35)
	assert_eq(online.storages, expected.storages)
	assert_eq(online.crops, expected.crops)
	assert_eq(online.coins, expected.coins)
	assert_eq(service.crop_automation.sequence, 5)

func test_team_size_comparison_shows_parallel_progress_on_the_same_field() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var empty: Dictionary = adapter.capture("crop_team_test", 1, FIXED_TIME)
	var progress: Array[int] = []
	var metrics: Array[Dictionary] = []
	for count: int in [1, 3, 5]:
		assert_true(adapter.restore(empty, FIXED_TIME).ok)
		_hire(count)
		source.add(SEED, 5)
		var started: int = Time.get_ticks_usec()
		service.advance(FIXED_TIME + 15)
		progress.append(service.crop_automation.sequence)
		metrics.append({"workers": count, "planted_in_15s": service.crop_automation.sequence, "simulation_ms": float(Time.get_ticks_usec() - started) / 1000.0})
	assert_gt(progress[2], progress[0], "Five workers must make more progress than one on the same field")
	assert_gte(progress[1], progress[0])
	print("CROP_TEAM_COMPARISON ", JSON.stringify(metrics))

func test_resuming_unpaid_worker_releases_prepared_plot_taken_by_a_colleague() -> void:
	_hire(2)
	source.add(SEED, 2)
	var first: Dictionary = service.records_for("crop")[0]
	var second: Dictionary = service.records_for("crop")[1]
	service.busy = true
	assert_true(service.crop_policy.commit(first, service.crop_policy.task("till", cells[0], 5, SEED)))
	service.busy = false
	first.active = false
	first.paused_at = FIXED_TIME
	second.task = service.crop_policy.task("plant", cells[0], 4, SEED)
	second.task.merge({"point": [0, 0], "work_at": FIXED_TIME + 5, "finish_at": FIXED_TIME + 7, "base_point": [0, 0], "attempt": 0})
	first.active = true
	service._resume_task(first, FIXED_TIME + 1)
	assert_eq(service.crop_automation.prepared_for(first.id), Vector2i(-1, -1))
	assert_true(service.target_available(second, second.task))

func test_worker_baskets_and_recovery_transfers_address_exact_id() -> void:
	_hire(2)
	var rows: Array[Dictionary] = service.records_for("crop")
	var produce: ItemDefinition = (SEED.crop as CropDefinition).harvest_item
	service.bag_for(rows[0].id).add(produce, 3)
	service.bag_for(rows[1].id).add(produce, 7)
	assert_eq(service.transfer(rows[1].id, world.player.selection.inventory, false, false), 7)
	assert_eq(service.bag_for(rows[0].id).count_item(produce.item_id), 3)
	assert_eq(service.bag_for(rows[1].id).count_item(produce.item_id), 0)
