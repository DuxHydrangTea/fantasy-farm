extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FEED: ItemDefinition = preload("res://items/feeds/poultry_feed.tres")
var world: FarmWorld
var source: InventoryComponent
var now: float
var origin: Vector2i = Vector2i(48, 30)

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(1000000)
	world.land.state.restore_columns(48, 4)
	now = world.farming.time_manager.now()
	var fixed: float = now
	world.farming.time_manager.clock_source = func() -> float: return fixed
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	source = world.storages.inventory("farm_supply_storage")
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(origin))
	world.player.animation.face(Vector2.DOWN)
	var upgrades: Dictionary = ToolUpgradeState.fresh()
	for key: String in upgrades:
		upgrades[key] = {"level": 6, "selected_size": 6}
	world.tool_upgrade_state.restore(upgrades)
	await wait_physics_frames(2)

func _field(size: int, facing: Vector2i = Vector2i.DOWN) -> Array[Vector2i]:
	world.farming.restore_soil([])
	world.tool_upgrade_state.select_size(&"sowing", size)
	world.player.animation.face(Vector2(facing))
	var cells: Array[Vector2i] = FarmingAreaPolicy.cells(origin, facing, size)
	assert_eq(world.farming.apply_area(&"tool", cells, null, -1, null, world.player).changed, size * size)
	return cells

func _impact() -> void:
	world.player.animation.animated_sprite.stop()
	world.player.animation.animated_sprite.frame = 3
	world.player.farming_actions._on_frame_changed()

func _food() -> AnimalTrough:
	for pen: AnimalPen in world.workers.bridge.pens():
		for node: Node in pen.get_children():
			if node is AnimalTrough and node.kind == AnimalTrough.Kind.FOOD and node.feed_item.matches(FEED):
				return node as AnimalTrough
	return null

func test_all_six_sizes_and_four_directions_spend_shared_seeds_without_any_in_bag() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	bag.remove(SEED.item_id, bag.count_item(SEED.item_id))
	assert_true(world.player.selection.select_storage_seed(SEED.item_id))
	for facing: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		for size: int in range(1, 7):
			var cells: Array[Vector2i] = _field(size, facing)
			source.add(SEED, size * size)
			var result: Dictionary = world.storages.plant_from_storage(SEED.item_id, world.player.selection.revision, cells)
			assert_eq(result.changed, size * size)
			assert_eq(result.seed_spent, size * size)
			assert_eq(world.farming.crop_cells().size(), size * size)
			assert_eq(source.count_item(SEED.item_id), 0)
			assert_eq(bag.count_item(SEED.item_id), 0)

func test_five_seeds_preview_and_impact_match_and_do_not_use_extra_bag_seeds() -> void:
	_field(6)
	source.add(SEED, 5)
	world.player.selection.select_storage_seed(SEED.item_id)
	var ready: int = 0
	for row: Dictionary in world.player.farming_actions.preview():
		ready += 1 if row.ready else 0
	assert_eq(ready, 5)
	var bag_count: int = world.player.selection.inventory.count_item(SEED.item_id)
	assert_true(world.player.state.use_selected_tool())
	_impact()
	_impact()
	assert_eq(world.farming.crop_cells().size(), 5)
	assert_eq(source.count_item(SEED.item_id), 0)
	assert_eq(world.player.selection.inventory.count_item(SEED.item_id), bag_count)

func test_source_reduction_before_impact_limits_planting_to_remaining_stock() -> void:
	_field(6)
	source.add(SEED, 36)
	world.player.selection.select_storage_seed(SEED.item_id)
	assert_true(world.player.state.use_selected_tool())
	source.remove(SEED.item_id, 31)
	_impact()
	assert_eq(world.farming.crop_cells().size(), 5)
	assert_eq(source.count_item(SEED.item_id), 0)

func test_switching_seed_away_and_back_or_opening_menu_cancels_frozen_action() -> void:
	_field(2)
	source.add(SEED, 8)
	source.add(OTHER, 4)
	world.player.selection.select_storage_seed(SEED.item_id)
	assert_true(world.player.state.use_selected_tool())
	world.player.selection.select_storage_seed(OTHER.item_id)
	world.player.selection.select_storage_seed(SEED.item_id)
	_impact()
	assert_eq(world.farming.crop_cells().size(), 0)
	assert_eq(source.count_item(SEED.item_id), 8)
	world.player.state.transition_to(StateComponent.State.IDLE)
	assert_true(world.player.state.use_selected_tool())
	world.seed_picker.open_picker()
	_impact()
	assert_eq(world.farming.crop_cells().size(), 0)
	world.seed_picker.close(false)
	world.player.selection.select_slot(0)
	assert_true(world.player.selection.storage_seed_id.is_empty())
	assert_eq(world.player.selection.get_selected_action(), &"tool")

func test_hotbar_crop_seed_also_uses_warehouse_and_never_falls_back_to_bag() -> void:
	_field(1)
	world.player.selection.select_slot(2)
	assert_eq(world.player.selection.get_selected_item(), SEED)
	assert_true(world.player.state.use_selected_tool())
	_impact()
	assert_eq(world.farming.crop_cells().size(), 0)
	assert_eq(world.player.selection.inventory.count_item(SEED.item_id), 24)

func test_selection_save_migration_validation_and_save_before_impact() -> void:
	_field(2)
	source.add(SEED, 4)
	world.player.selection.select_storage_seed(SEED.item_id)
	assert_true(world.player.state.use_selected_tool())
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("supply_test", 1, now)
	assert_eq(saved.storage_seed, String(SEED.item_id))
	assert_eq(saved.crops.size(), 0)
	assert_true(adapter.restore(saved, now).ok)
	_impact()
	assert_eq(world.farming.crop_cells().size(), 0)
	assert_eq(world.player.selection.storage_seed_id, SEED.item_id)
	assert_eq(world.storages.inventory("farm_supply_storage").count_item(SEED.item_id), 4)
	var bad: Dictionary = saved.duplicate(true)
	bad.storage_seed = "poultry_feed"
	assert_false(adapter.restore(bad, now).ok)
	var old: Dictionary = saved.duplicate(true)
	old.version = 24
	old.erase("storage_seed")
	var checked: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.storage_seed, "")
	assert_eq(checked.snapshot.storages, old.storages)
	assert_false(old.has("storage_seed"))

func test_only_correct_feed_from_storage_is_consumed_and_two_troughs_cannot_share_last_pack() -> void:
	var trough: AnimalTrough = _food()
	assert_not_null(trough)
	trough.stock = 0
	world.player.global_position = trough.global_position + Vector2(0, 20)
	assert_eq(world.storages.refill_feed(trough, true), 0, "Feed in the bag is not a fallback")
	source.add(load("res://items/feeds/livestock_feed.tres") as ItemDefinition, 1)
	assert_eq(world.storages.refill_feed(trough, true), 0, "Wrong feed is never consumed")
	source.add(FEED, 1)
	var other: AnimalTrough = preload("res://scenes/animals/feed_trough.tscn").instantiate() as AnimalTrough
	other.capacity = 600
	other.stock = 0
	world.add_child(other)
	other.global_position = trough.global_position
	assert_eq(world.storages.refill_feed(trough, true), FEED.food_units_per_item)
	assert_eq(world.storages.refill_feed(other, true), 0)
	assert_eq(source.count_item(FEED.item_id), 0)
	assert_eq(world.player.selection.inventory.count_item(FEED.item_id), 5)

func test_reserve_and_observers_preserve_whole_feed_packs_and_hold_storage_lock() -> void:
	var trough: AnimalTrough = _food()
	trough.capacity = 650
	trough.stock = 640
	world.player.global_position = trough.global_position + Vector2(0, 20)
	source.add(FEED, 1)
	var observed: Array[bool] = []
	source.changed.connect(func() -> void:
		observed.append(world.storages.busy)
		assert_eq(trough.stock, 650)
		assert_eq(trough.feed_reserve, FEED.food_units_per_item - 10)
		assert_eq(world.storages.refill_feed(trough, true), 0)
	)
	assert_eq(world.storages.refill_feed(trough, true), 10)
	assert_eq(observed, [true])
	trough.stock = 350
	assert_eq(world.storages.refill_feed(trough, true), FEED.food_units_per_item - 10)
	assert_eq(trough.feed_reserve, 0)
	assert_eq(trough.stock, 350 + FEED.food_units_per_item - 10)

func test_old_basket_feed_migrates_partially_and_remainder_can_be_recovered() -> void:
	var data: Dictionary = world.storages.capture()
	data.farm_supply_storage = {"slot_count": 1, "stack_cap": 2, "slots": [{"item": "poultry_feed", "count": 1, "tiers": [1, 0, 0]}]}
	world.storages.restore(data, SaveCatalog.new())
	world.workers.hire("crop")
	world.workers.dismiss("crop")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("supply_test", 1, now)
	saved.workers.rows[0].basket[0] = {"item": "poultry_feed", "count": 5, "tiers": [5, 0, 0]}
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(world.storages.inventory("farm_supply_storage").count_item(FEED.item_id), 2)
	assert_eq(world.workers.bag_for("crop").count_item(FEED.item_id), 4)
	assert_eq(world.workers.transfer("crop", world.player.selection.inventory, false, true), 4)
	assert_eq(world.workers.bag_for("crop").count_item(FEED.item_id), 0)

func test_support_checks_seeds_and_produce_in_both_warehouses() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	for i: int in range(bag.slot_count):
		var item: ItemDefinition = bag.get_slot_item(i)
		if item != null and item.item_type in [ItemDefinition.ItemType.SEED, ItemDefinition.ItemType.PRODUCE]:
			bag.remove(item.item_id, bag.count_item(item.item_id))
	world.player.wallet.set_balance(0)
	var support: StarterSupport = StarterSupport.new(world)
	assert_true(support.quote().ok)
	source.add(SEED, 1)
	assert_false(support.quote().ok)
	source.remove(SEED.item_id, 1)
	world.workers.output_inventory().add(load("res://items/trees/apple.tres") as ItemDefinition, 1)
	assert_false(support.quote().ok)

func test_animal_purchase_uses_valid_scene_and_current_prices_with_atomic_notifications() -> void:
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var offer: AnimalShopOffer = stock.animal_offers[0]
	var trades: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, world.farming.time_manager)
	var observed: Array[int] = []
	world.player.wallet.changed.connect(func(_balance: int) -> void:
		observed.append(trades.owned_animals().size())
		assert_false(trades.buy(offer, 1).ok)
	)
	var before: int = world.player.wallet.balance
	var result: Dictionary = trades.buy(offer, 2)
	assert_true(result.ok)
	assert_eq(world.player.wallet.balance, before - 2 * offer.price)
	assert_eq(observed, [2])
	if not result.ok:
		return
	for animal: AnimalActor in result.animals:
		assert_eq(animal.growth.age_seconds, 0.0)
		assert_eq(animal.definition, offer.animal)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	assert_true(SaveSchema.validate(adapter.capture("supply_test", 1, now), adapter.catalog).ok)
