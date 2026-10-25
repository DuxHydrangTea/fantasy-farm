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

func test_prewater_and_dry_afterwards_keep_silver_without_changing_deadline() -> void:
	source.add(SEED, 1)
	assert_true(_commit(service.crop_policy.task("till", cell, 5, SEED)))
	assert_true(world.farming.water(cell, world.player))
	assert_true(_commit(service.crop_policy.task("plant", cell, 4, SEED)))
	var crop: Crop = world.farming.get_crop(cell)
	var deadline: float = crop.matures_at
	assert_true(crop.watered)
	world.farming.evaporate_soil(21601)
	assert_eq(crop.harvest_tier(), 1)
	assert_eq(crop.matures_at, deadline)
	assert_eq(world.farming.get_soil_state(cell), FarmingController.Soil.DRY)

func test_rain_and_batch_water_mark_existing_crop_and_worker_plants_on_wet_soil() -> void:
	_plant()
	var crop: Crop = world.farming.get_crop(cell)
	assert_eq(crop.harvest_tier(), 0)
	world.farming.rain_water()
	assert_eq(crop.harvest_tier(), 1)
	var other: Vector2i = cell + Vector2i.RIGHT
	source.add(OTHER, 1)
	assert_true(_commit(service.crop_policy.task("plant", other, 4, OTHER)))
	assert_true(world.farming.get_crop(other).watered)

func test_root_requires_water_only_once_and_never_changes_growth_time() -> void:
	_plant()
	var crop: Crop = world.farming.get_crop(cell)
	var deadline: float = crop.matures_at
	var bag: InventoryComponent = world.player.selection.inventory
	var tonic: ItemDefinition = load("res://items/boosters/root_tonic.tres") as ItemDefinition
	bag.add(tonic, 2)
	var slot: int = -1
	for i: int in range(bag.slot_count):
		if bag.get_slot_item(i) == tonic:
			slot = i
	var booster: BoosterService = BoosterService.new()
	assert_false(booster.use(world.farming, cell, null, bag, slot, tonic, world.player).ok)
	assert_eq(bag.count_item(tonic.item_id), 2)
	crop.mark_watered()
	assert_true(booster.use(world.farming, cell, null, bag, slot, tonic, world.player).ok)
	assert_eq(crop.harvest_tier(), 2)
	assert_eq(bag.count_item(tonic.item_id), 1)
	assert_eq(crop.matures_at, deadline)
	assert_false(booster.use(world.farming, cell, null, bag, slot, tonic, world.player).ok)
	assert_eq(bag.count_item(tonic.item_id), 1)

func test_worker_harvest_sends_gold_to_warehouse_and_transfers_preserve_tiers() -> void:
	_plant()
	var crop: Crop = world.farming.get_crop(cell)
	crop.mark_watered()
	assert_true(crop.apply_root())
	var id: StringName = crop.definition.harvest_item.item_id
	var amount: int = crop.definition.harvest_amount
	clock[0] = now + 100
	assert_true(_commit(service.crop_policy.task("harvest", cell, 0)))
	var output: InventoryComponent = service.output_inventory()
	assert_eq(output.count_item(id, 2), amount)
	assert_eq(output.count_item(id), 0)
	assert_eq(service.bag_for("crop").count_item(id, -1), 0)
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = access.global_position
	assert_true(world.storages.transfer_all("produce_warehouse", world.player.selection.inventory, false).ok)
	assert_eq(world.player.selection.inventory.count_item(id, 2), amount)
	assert_true(world.storages.transfer_all("produce_warehouse", world.player.selection.inventory, true).ok)
	assert_eq(output.count_item(id, 2), amount)

func test_v28_roundtrip_and_v26_migration_preserve_resources_and_grant_silver() -> void:
	_plant()
	var crop: Crop = world.farming.get_crop(cell)
	crop.mark_watered()
	crop.apply_root()
	var output: InventoryComponent = service.output_inventory()
	output.add(SEED.crop.harvest_item as ItemDefinition, 3, 2)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var data: Dictionary = adapter.capture("quality_test", 1, now)
	assert_true(SaveSchema.validate(data, adapter.catalog).ok)
	assert_true(adapter.restore(data, now).ok)
	assert_true(world.farming.get_crop(cell).root_boost)
	assert_eq(service.output_inventory().count_item(SEED.crop.harvest_item.item_id, 2), 3)
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 26
	for row: Dictionary in legacy.crops:
		row.erase("watered")
		row.erase("root_boost")
	for stack: Dictionary in legacy.inventory:
		stack.erase("tiers")
	for storage: Dictionary in legacy.storages.values():
		for stack: Dictionary in storage.slots:
			stack.erase("tiers")
	for row: Dictionary in legacy.workers.rows:
		for stack: Dictionary in row.basket:
			stack.erase("tiers")
	var original: String = JSON.stringify(legacy)
	var migrated: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(migrated.ok)
	assert_eq(JSON.stringify(legacy), original)
	assert_eq(migrated.snapshot.version, SaveSchema.VERSION)
	assert_true(migrated.snapshot.crops[0].watered)
	assert_false(migrated.snapshot.crops[0].root_boost)
	assert_eq(migrated.snapshot.storages.produce_warehouse.slots[0].tiers, [3, 0, 0])
	data.crops[0].watered = false
	assert_false(SaveSchema.validate(data, adapter.catalog).ok)
	data.crops[0].watered = true
	data.storages.produce_warehouse.slots[0].tiers = [3, 0, 3]
	assert_false(SaveSchema.validate(data, adapter.catalog).ok)

func test_batch_watering_marks_crop_and_full_warehouse_retains_gold() -> void:
	_plant()
	var crop: Crop = world.farming.get_crop(cell)
	assert_eq(world.farming.apply_area(&"water", [cell], null, -1, null, world.player).changed, 1)
	assert_true(crop.watered)
	crop.apply_root()
	var output: InventoryComponent = service.output_inventory()
	var filler: ItemDefinition = load("res://items/trees/wood.tres") as ItemDefinition
	output.add(filler, output.capacity_for(filler))
	clock[0] = now + 100
	assert_false(world.farming.harvest(cell, output))
	assert_same(world.farming.get_crop(cell), crop)
	assert_eq(crop.harvest_tier(), 2)
