extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
var world: FarmWorld
var service: WorkerService
var source: InventoryComponent
var clock: Array[float]
var now: float
var original_clock: Callable
var original_clock_floor: float
var cell: Vector2i = Vector2i(48, 30)

func before_each() -> void:
	original_clock = TimeManager.clock_source
	original_clock_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(1000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	now = world.farming.time_manager.now()
	clock = [now]
	var manual_clock: Array[float] = clock
	world.farming.time_manager.clock_source = func() -> float: return manual_clock[0]
	world.farming.restore_soil([])
	service = world.workers
	source = world.storages.inventory("farm_supply_storage")
	assert_eq(service.hire("crop"), "")
	_limit([cell, cell + Vector2i.RIGHT])

func after_each() -> void:
	world.farming.time_manager.clock_source = original_clock
	world.farming.time_manager._last_timestamp = original_clock_floor

func _limit(cells: Array[Vector2i]) -> void:
	service.crop_policy.cells = cells.duplicate()
	service.crop_policy.cached_columns = world.land.state.unlocked_columns
	service.crop_policy.soils.clear()
	for point: Vector2i in cells:
		service.crop_policy.soils[point] = int(world.farming.get_soil_state(point))

func _commit(job: Dictionary) -> bool:
	service.busy = true
	var result: bool = service.bridge.commit(service.record("crop"), service.feed_inventory("crop"), job)
	service.busy = false
	return result

func _plant(point: Vector2i = Vector2i(48, 30), item: ItemDefinition = SEED) -> void:
	source.add(item, 1)
	assert_true(_commit(service.crop_policy.task("till", point, 5, item)))
	assert_true(_commit(service.crop_policy.task("plant", point, 4, item)))

func test_hires_with_auto_plant_and_uses_any_seed_without_player_selection() -> void:
	assert_true(service.crop_automation.auto_plant)
	assert_false(service.crop_automation.auto_fertilize)
	source.add(SEED, 1)
	source.add(OTHER, 1)
	var selected: StringName = world.player.selection.get_selected_item().item_id
	service.advance(now + 30)
	assert_eq(world.farming.crop_cells().size(), 2)
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_eq(source.count_item(OTHER.item_id), 0)
	assert_eq(world.player.selection.get_selected_item().item_id, selected)
	var species: Array[String] = []
	for point: Vector2i in world.farming.crop_cells():
		species.append(String(world.farming.get_crop(point).definition.crop_id))
	assert_true("carrot" in species)
	assert_true("radish" in species)

func test_tilling_does_not_spend_seed_and_failed_plant_preserves_prepared_plot() -> void:
	source.add(SEED, 1)
	var till: Dictionary = service.crop_policy.planting_task(service.record("crop"))
	assert_eq(till.kind, "till")
	assert_true(_commit(till))
	assert_eq(source.count_item(SEED.item_id), 1)
	source.remove(SEED.item_id, 1)
	var plant: Dictionary = service.crop_policy.task("plant", cell, 4, SEED)
	assert_false(_commit(plant))
	assert_eq(world.farming.get_soil_state(service.crop_automation.prepared), FarmingController.Soil.DRY)
	assert_true(service.crop_policy.planting_task(service.record("crop")).is_empty())
	source.add(OTHER, 1)
	var replacement: Dictionary = service.crop_policy.planting_task(service.record("crop"))
	assert_eq(replacement.kind, "plant")
	assert_eq(replacement.item, String(OTHER.item_id))
	assert_true(_commit(replacement))
	assert_eq(source.count_item(OTHER.item_id), 0)

func test_replants_after_harvest_and_prefers_never_planted_plot_before_old_one() -> void:
	_plant()
	var crop: Crop = world.farming.get_crop(cell)
	crop.progress = 1.0
	assert_true(world.farming.harvest(cell, service.output_inventory()))
	source.add(OTHER, 2)
	var next: Dictionary = service.crop_policy.planting_task(service.record("crop"))
	assert_eq(next.cell, [cell.x + 1, cell.y])
	assert_eq(next.kind, "till")
	assert_true(_commit(next))
	assert_true(_commit(service.crop_policy.planting_task(service.record("crop"))))
	var again: Dictionary = service.crop_policy.planting_task(service.record("crop"))
	assert_eq(again.cell, [cell.x, cell.y])
	assert_eq(again.kind, "plant")
	assert_true(_commit(again))
	assert_eq(service.output_inventory().count_item((SEED.crop as CropDefinition).harvest_item.item_id, -1), (SEED.crop as CropDefinition).harvest_amount)
	assert_eq(world.farming.get_crop(cell).definition, OTHER.crop)

func test_does_not_use_bag_or_feed_flowers_and_saplings_as_seeds() -> void:
	source.add(load("res://items/feeds/poultry_feed.tres") as ItemDefinition, 10)
	source.add(FERTILIZER, 2)
	assert_null(service.crop_policy.first_item())
	assert_true(service.crop_policy.planting_task(service.record("crop")).is_empty())
	assert_eq(world.player.selection.inventory.count_item(SEED.item_id), 24)
	var supplies: FarmStorageDefinition = world.storages.definition("farm_supply_storage")
	assert_true(supplies.accepts(FERTILIZER))
	assert_false(supplies.accepts(load("res://items/boosters/animal_tonic.tres") as ItemDefinition))
	assert_false(supplies.accepts(load("res://items/seeds/flower_01_seed.tres") as ItemDefinition))
	assert_false(supplies.accepts(load("res://items/trees/apple_sapling.tres") as ItemDefinition))

func test_fertilizes_own_crop_once_and_spends_exactly_one_from_storage() -> void:
	_plant()
	source.add(FERTILIZER, 2)
	assert_eq(service.configure_crop(true, true, false), "")
	var crop: Crop = world.farming.get_crop(cell)
	var deadline: float = crop.matures_at
	var job: Dictionary = service.crop_policy.fertilizer_task(cell, crop)
	assert_false(job.is_empty())
	assert_true(_commit(job))
	assert_true(crop.fertilized)
	assert_almost_eq(crop.matures_at, deadline - (SEED.crop as CropDefinition).growth_seconds * 0.2, 0.001)
	assert_eq(source.count_item(FERTILIZER.item_id), 1)
	assert_false(_commit(job))
	assert_eq(source.count_item(FERTILIZER.item_id), 1)

func test_missing_late_or_replaced_crop_never_spends_fertilizer() -> void:
	_plant()
	source.add(FERTILIZER, 1)
	service.configure_crop(true, true, false)
	var crop: Crop = world.farming.get_crop(cell)
	var job: Dictionary = service.crop_policy.fertilizer_task(cell, crop)
	clock[0] += 30
	assert_false(_commit(job), "At exactly 50 percent the fertilizer window is closed")
	assert_eq(source.count_item(FERTILIZER.item_id), 1)
	crop.progress = 1.0
	assert_true(world.farming.harvest(cell, service.output_inventory()))
	source.add(OTHER, 1)
	assert_eq(world.farming.apply_area(&"plant", [cell], source, -1, OTHER, world.player, true).changed, 1)
	assert_false(_commit(job))
	assert_true(service.crop_policy.fertilizer_task(cell, world.farming.get_crop(cell)).is_empty())
	assert_false(world.farming.get_crop(cell).fertilized)
	assert_eq(source.count_item(FERTILIZER.item_id), 1)

func test_toggle_cancels_old_seed_task_and_pause_resume_preserves_remaining_work() -> void:
	source.add(SEED, 2)
	service.advance(now)
	var row: Dictionary = service.record("crop")
	var old: Dictionary = row.task.duplicate(true)
	assert_eq(service.configure_crop(false, false, false), "")
	assert_false(_commit(old))
	assert_eq(source.count_item(SEED.item_id), 2)
	service.configure_crop(true, false, false)
	service.advance(now)
	var finish: float = float(row.task.finish_at)
	service.configure_crop(true, false, true)
	service.advance(now + 100)
	clock[0] = now + 100
	assert_eq(source.count_item(SEED.item_id), 2)
	service.configure_crop(true, false, false)
	assert_almost_eq(float(row.task.finish_at), finish + 100, 0.001)
	service.advance(now + 130)
	assert_gt(world.farming.crop_cells().size(), 0)

func test_schema_v25_migrates_care_only_and_v26_roundtrips_work_and_fertilizer() -> void:
	_plant()
	source.add(FERTILIZER, 1)
	service.configure_crop(true, true, false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var current: Dictionary = adapter.capture("crop_auto_test", 1, now)
	assert_true(SaveSchema.validate(current, adapter.catalog).ok)
	assert_true(adapter.restore(current, now).ok)
	assert_true(service.crop_automation.auto_plant)
	assert_true(service.crop_automation.auto_fertilize)
	assert_true(service.crop_automation.owns(cell, world.farming.get_crop(cell)))
	var legacy: Dictionary = current.duplicate(true)
	legacy.version = 25
	legacy.workers.erase("crop_automation")
	# v25 never contains the new task kinds.
	legacy.workers.rows[0].task = {}
	var checked: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(checked.ok)
	assert_eq(int(checked.snapshot.version), SaveSchema.VERSION)
	assert_false(checked.snapshot.workers.crop_automation.auto_plant)
	assert_false(legacy.workers.has("crop_automation"))
	var bad: Dictionary = current.duplicate(true)
	bad.workers.crop_automation.plots[0].cell = [0, 0]
	assert_false(adapter.restore(bad, now).ok)

func test_blocked_or_player_planted_plot_is_not_destroyed_or_used_twice() -> void:
	source.add(SEED, 2)
	var job: Dictionary = service.crop_policy.task("till", cell, 5, SEED)
	world.farming.set_cell_occupied(cell, true)
	assert_false(_commit(job))
	assert_eq(source.count_item(SEED.item_id), 2)
	world.farming.set_cell_occupied(cell, false)
	assert_true(_commit(job))
	var prepared: Dictionary = service.crop_policy.task("plant", cell, 4, SEED)
	assert_eq(world.farming.apply_area(&"plant", [cell], source, -1, SEED, world.player, true).changed, 1)
	assert_false(_commit(prepared))
	assert_eq(source.count_item(SEED.item_id), 1)
	assert_false(service.crop_automation.owns(cell, world.farming.get_crop(cell)))

func test_plant_notification_blocks_reentry_and_exposes_complete_crop_batch() -> void:
	source.add(SEED, 1)
	assert_true(_commit(service.crop_policy.task("till", cell, 5, SEED)))
	var job: Dictionary = service.crop_policy.task("plant", cell, 4, SEED)
	var observed: Array[int] = []
	source.changed.connect(func() -> void:
		assert_true(world.storages.busy)
		assert_true(service.busy)
		observed.append(world.farming.crop_cells().size())
		assert_false(service.crop_policy.commit(service.record("crop"), job))
	)
	assert_true(_commit(job))
	assert_eq(observed, [1])
	assert_eq(source.count_item(SEED.item_id), 0)

func test_manual_pause_overlapping_unpaid_days_does_not_double_delay_task() -> void:
	source.add(SEED, 1)
	service.advance(now)
	var row: Dictionary = service.record("crop")
	var finish: float = float(row.task.finish_at)
	service.configure_crop(true, false, true)
	world.player.wallet.set_balance(0)
	var first_dawn: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	service.advance(first_dawn)
	clock[0] = first_dawn
	assert_false(row.active)
	service.configure_crop(true, false, false)
	assert_eq(source.count_item(SEED.item_id), 1)
	world.player.wallet.set_balance(int(WorkerRole.WAGES.crop))
	var second_dawn: float = first_dawn + 86400
	service.advance(second_dawn)
	assert_true(row.active)
	assert_almost_eq(float(row.task.finish_at), finish + second_dawn - now, 0.001)

func test_full_field_48h_single_and_segmented_loops_match_with_fertilizer_and_no_quota() -> void:
	# Keep actual terrain/API, reserve the rest as occupied for a repeatable small farm.
	for y: int in range(LandExpansionState.REGION.position.y, LandExpansionState.REGION.end.y):
		for x: int in range(LandExpansionState.REGION.position.x, LandExpansionState.REGION.end.x):
			var point: Vector2i = Vector2i(x, y)
			if point != cell and point != cell + Vector2i.RIGHT:
				world.farming.set_cell_occupied(point, true)
	service.crop_policy.invalidate()
	var actor: WorkerActor = service.actors.crop as WorkerActor
	actor.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell + Vector2i.UP))
	service.record("crop").position = WorkerRole.pair(actor.global_position)
	source.add(SEED, 8)
	source.add(OTHER, 4)
	source.add(FERTILIZER, 12)
	service.configure_crop(true, true, false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("crop_auto_test", 1, now)
	var started: int = Time.get_ticks_usec()
	service.advance(now + 172800)
	var single: Dictionary = adapter.capture("crop_auto_test", 2, now + 172800)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	assert_true(adapter.restore(checkpoint, now).ok)
	for hour: int in range(1, 49):
		service.advance(now + hour * 3600)
	var stepped: Dictionary = adapter.capture("crop_auto_test", 2, now + 172800)
	assert_eq(stepped.storages, single.storages)
	assert_eq(stepped.workers, single.workers)
	assert_eq(stepped.crops, single.crops)
	assert_eq(stepped.coins, single.coins)
	assert_eq(service.crop_automation.sequence, 12)
	assert_eq(world.storages.inventory("farm_supply_storage").count_item(SEED.item_id), 0)
	assert_true(SaveSchema.validate(stepped, adapter.catalog).ok)
	assert_true(adapter.restore(stepped, now + 172800).ok)
	assert_eq(service.crop_automation.sequence, 12)
	print("CROP_AUTOMATION_48H ", JSON.stringify({"elapsed_ms": elapsed, "plantings": service.crop_automation.sequence, "history_cells": service.crop_automation.plots.size()}))

func test_full_1632_plot_field_has_no_daily_quota_and_consumes_only_supplied_stock() -> void:
	world.land.state.restore_columns(48, 4)
	service.crop_policy.invalidate()
	source.add(SEED, 48)
	source.add(OTHER, 12)
	source.add(FERTILIZER, 60)
	service.configure_crop(true, true, false)
	var started: int = Time.get_ticks_usec()
	service.advance(now + 172800)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	assert_gt(service.crop_policy.cells.size(), 1000, "The real open field is indexed; no 144-plot cap")
	assert_eq(service.crop_automation.sequence, 60, "No daily planting quota")
	assert_eq(service.crop_automation.plots.size(), 60, "Never-planted plots are not starved by near repeats")
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_eq(source.count_item(OTHER.item_id), 0)
	assert_eq(service.output_inventory().count_item((SEED.crop as CropDefinition).harvest_item.item_id, -1), 5350, "Layout v1: 48 carrot crops, including 11 fertile plots")
	assert_eq(service.output_inventory().count_item((OTHER.crop as CropDefinition).harvest_item.item_id, -1), 12 * (OTHER.crop as CropDefinition).harvest_amount)
	print("CROP_AUTOMATION_FIELD ", JSON.stringify({"elapsed_ms": elapsed, "indexed_cells": service.crop_policy.cells.size(), "plantings": service.crop_automation.sequence, "fertilizer_left": source.count_item(FERTILIZER.item_id)}))
