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
	world.trees.reset()
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

func _wood_offer() -> ShopOffer:
	for offer: ShopOffer in (load("res://resources/shops/farm_supply.tres") as ShopCatalog).offers:
		if offer.item.item_id == WoodMarket.ITEM:
			return offer
	return null

func _shop() -> ShopService:
	var result: ShopService = ShopService.new(load("res://resources/shops/farm_supply.tres") as ShopCatalog, world.player.wallet, world.player.selection.inventory)
	result.world = world
	return result

func _tree(point: Vector2i = Vector2i(68, 61), mature: bool = false) -> TimberTree:
	var definition: TreeDefinition = world.trees.definitions[&"oak"]
	var tree: TimberTree = world.trees.create_tree(point, definition, now - definition.growth_seconds if mature else now) as TimberTree
	tree.refresh(now)
	return tree

func _stump(point: Vector2i = Vector2i(68, 61)) -> TimberTree:
	var tree: TimberTree = _tree(point, true)
	for i: int in range(tree.definition.chop_hits):
		assert_true(tree.chop(world.player.selection.inventory))
	return tree

func test_shared_daily_stock_exact_limit_and_failed_purchase_spends_nothing() -> void:
	var shop: ShopService = _shop()
	var other: ShopService = _shop()
	var bag: InventoryComponent = world.player.selection.inventory
	var balance: int = world.player.wallet.balance
	assert_eq(_wood_offer().price, 63)
	assert_eq((load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog).find(&"wood").price, 1)
	assert_true(shop.buy(_wood_offer(), 12).ok)
	assert_eq(world.wood_market.used(now), 12)
	assert_false(other.buy(_wood_offer(), 19).ok)
	assert_eq(bag.count_item(&"wood"), 12)
	assert_eq(world.player.wallet.balance, balance - 12 * 63)
	assert_true(other.buy(_wood_offer(), 18).ok)
	assert_eq(world.wood_market.remaining(now), 0)
	assert_false(shop.buy(_wood_offer(), 1).ok)
	assert_eq(bag.count_item(&"wood"), 30)

func test_daily_reset_uses_shared_dawn_and_reload_does_not_restock_same_day() -> void:
	var shop: ShopService = _shop()
	assert_true(shop.buy(_wood_offer(), 30).ok)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("wood_test", 1, now)
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(world.wood_market.remaining(now), 0)
	var dawn: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	clock[0] = dawn - 0.001
	assert_false(shop.buy(_wood_offer(), 1).ok)
	clock[0] = dawn
	assert_true(shop.buy(_wood_offer(), 1).ok)
	assert_eq(world.wood_market.used(dawn), 1)
	assert_eq(world.player.selection.inventory.count_item(&"wood"), 31)
	assert_eq(world.wood_market.remaining(dawn - 100), 29)

func test_stock_lock_spans_notifications_for_another_vendor_and_save() -> void:
	var shop: ShopService = _shop()
	var other: ShopService = _shop()
	var observed: Array[int] = []
	world.player.selection.inventory.changed.connect(func() -> void:
		observed.append(world.wood_market.used(now))
		assert_false(other.buy(_wood_offer(), 1).ok)
		assert_true(world.wood_market.busy)
	)
	assert_true(shop.buy(_wood_offer(), 12).ok)
	assert_eq(observed, [12])
	assert_false(world.wood_market.busy)

func test_full_bag_poor_wallet_and_loading_never_consume_daily_stock() -> void:
	var shop: ShopService = _shop()
	var bag: InventoryComponent = world.player.selection.inventory
	world.tool_upgrades.profile_ready = false
	assert_false(shop.buy(_wood_offer(), 1).ok)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(0)
	assert_false(shop.buy(_wood_offer(), 1).ok)
	world.player.wallet.set_balance(10000)
	var filler: ItemDefinition = load("res://items/trees/root_wood.tres") as ItemDefinition
	bag.add(filler, bag.capacity_for(filler))
	assert_false(shop.buy(_wood_offer(), 1).ok)
	assert_eq(world.wood_market.used(now), 0)
	assert_eq(world.player.wallet.balance, 10000)

func test_upgrade_requires_normal_wood_and_spends_warehouse_before_bag_atomically() -> void:
	world.land.state.restore_columns(13, 4)
	var upgrades: ToolUpgradeService = world.tool_upgrades
	assert_true(upgrades.purchase(&"hoe", 1, 30000, 0).ok)
	var balance: int = world.player.wallet.balance
	assert_eq(upgrades.quote(&"hoe").code, "insufficient_wood")
	var output: InventoryComponent = service.output_inventory()
	var bag: InventoryComponent = world.player.selection.inventory
	var wood: ItemDefinition = load("res://items/trees/wood.tres") as ItemDefinition
	output.add(wood, 4)
	bag.add(wood, 6)
	bag.add(wood, 2, 2)
	assert_eq(upgrades.quote(&"hoe").wood_cost, 10)
	var events: Array[int] = []
	output.changed.connect(func() -> void:
		events.append(upgrades.state.level(&"hoe"))
		assert_eq(bag.count_item(&"wood"), 0)
		assert_eq(world.player.wallet.balance, balance - 90000)
		assert_true(world.storages.busy)
		assert_false(upgrades.purchase(&"watering_can", 1, 30000, 0).ok)
	)
	assert_false(upgrades.purchase(&"hoe", 2, 90000, 11).ok)
	assert_eq(upgrades.wood_owned(), 10)
	assert_true(upgrades.purchase(&"hoe", 2, 90000, 10).ok)
	assert_eq(events, [3])
	assert_eq(output.count_item(&"wood"), 0)
	assert_eq(bag.count_item(&"wood", 2), 2)
	assert_false(world.storages.busy)

func test_young_tree_uproot_returns_one_sapling_and_no_root() -> void:
	var tree: TimberTree = _tree()
	var bag: InventoryComponent = world.player.selection.inventory
	var sapling: ItemDefinition = tree.definition.planting_item()
	var before: int = bag.count_item(sapling.item_id)
	assert_true(tree.dig(bag))
	assert_true(tree.removed)
	assert_eq(bag.count_item(sapling.item_id), before + 1)
	assert_eq(bag.count_item(&"root_wood"), 0)
	assert_false(tree.dig(bag))
	assert_false(world.trees.trees.has(Vector2i(68, 61)))

func test_mature_tree_must_be_chopped_before_single_hit_root_reward() -> void:
	var tree: TimberTree = _tree(Vector2i(68, 61), true)
	var bag: InventoryComponent = world.player.selection.inventory
	assert_false(tree.dig(bag))
	assert_eq(bag.count_item(&"root_wood"), 0)
	for i: int in range(tree.definition.chop_hits):
		assert_true(tree.chop(bag))
	assert_true(tree.stump)
	assert_eq(bag.count_item(&"wood"), 400)
	assert_true(tree.dig(bag))
	assert_eq(bag.count_item(&"root_wood"), 2)
	assert_false(tree.dig(bag))
	assert_eq(bag.count_item(&"root_wood"), 2)

func test_six_by_six_clears_staggered_stumps_and_young_trees_not_mature_trees() -> void:
	var first: TimberTree = _stump()
	var second: TimberTree = _stump(Vector2i(71, 61))
	var young: TimberTree = _tree(Vector2i(68, 64))
	var mature: TimberTree = _tree(Vector2i(71, 64), true)
	var anchor: Vector2i = world.farming.world_to_cell(first.global_position)
	var targets: Array[Vector2i] = FarmingAreaPolicy.cells(anchor + Vector2i(2, -1), Vector2i.DOWN, 6)
	var bag: InventoryComponent = world.player.selection.inventory
	assert_true(targets.has(world.farming.world_to_cell(second.global_position)))
	assert_true(targets.has(world.farming.world_to_cell(young.global_position)))
	var changes: Dictionary = world.farming.apply_area(&"tool", targets, bag, -1, null, world.player)
	assert_eq(changes.changed, 3)
	assert_true(first.removed and second.removed and young.removed)
	assert_false(mature.removed)
	assert_eq(bag.count_item(&"root_wood"), 4)
	assert_eq(world.trees.tool_cells.size(), 1)
	assert_eq(world.farming.apply_area(&"tool", targets, bag, -1, null, world.player).changed, 0)

func test_worker_cannot_clear_stumps_and_full_bag_preserves_young_tree() -> void:
	var stump: TimberTree = _stump()
	var key: Vector2i = world.farming.world_to_cell(stump.global_position)
	assert_eq(service.hire("crop"), "")
	var actor: WorkerActor = service.actors.crop as WorkerActor
	assert_false(world.farming.can_tool(key, actor, world.player.selection.inventory))
	assert_eq(world.farming.apply_area(&"tool", [key], world.player.selection.inventory, -1, null, actor).changed, 0)
	assert_false(stump.removed)
	var young: TimberTree = _tree(Vector2i(71, 61))
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 1
	add_child_autofree(bag)
	bag.add(InventoryComponent.HOE)
	assert_false(young.uproot(bag))
	assert_false(young.removed)
	assert_true(stump.dig(bag))
	var roots: int = 0
	for child: Node in world.get_children():
		if child is ItemPickup and child.item.item_id == &"root_wood":
			roots += child.amount
	assert_eq(roots, 2)

func test_v28_migration_preserves_stock_tools_and_stump_without_mutating_input() -> void:
	_stump()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var data: Dictionary = adapter.capture("forestry_test", 1, now)
	data.version = 28
	data.erase("wood_market")
	data.trees[0].root_hits = 2
	var before: String = JSON.stringify(data)
	var migrated: Dictionary = SaveSchema.validate(data, adapter.catalog)
	assert_true(migrated.ok)
	assert_eq(JSON.stringify(data), before)
	assert_eq(migrated.snapshot.version, SaveSchema.VERSION)
	assert_eq(migrated.snapshot.trees[0].root_hits, 0)
	assert_eq(migrated.snapshot.inventory, data.inventory)
	assert_eq(migrated.snapshot.tool_upgrades, data.tool_upgrades)
	assert_true(adapter.restore(data, now).ok)
	var restored: TimberTree = world.trees.trees[Vector2i(68, 61)] as TimberTree
	assert_true(restored.dig(world.player.selection.inventory))
	assert_eq(world.player.selection.inventory.count_item(&"root_wood"), 2)
	var current: Dictionary = adapter.capture("forestry_test", 2, now)
	current.wood_market.bought = 31
	assert_false(SaveSchema.validate(current, adapter.catalog).ok)
