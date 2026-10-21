extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var system: TreePlantation
var bag: InventoryComponent
var clock: FarmClock
var now: float = 1000.0

func before_each() -> void:
	now = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return now
	add_child_autofree(clock)
	world = WORLD.instantiate() as FarmWorld
	world.farming.time_manager = clock
	_clocks(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	system = world.trees
	bag = world.player.selection.inventory

func _clocks(node: Node) -> void:
	if node is AnimalNeedsComponent:
		(node as AnimalNeedsComponent).time_manager = clock
	if node is FlowerGarden:
		(node as FlowerGarden).time_manager = clock
	for child: Node in node.get_children():
		_clocks(child)

func _plant(id: String, cell: Vector2i) -> PerennialTree:
	var path: String = "res://items/trees/%s_sapling.tres" % id
	var item: ItemDefinition = load(path) as ItemDefinition
	bag.add(item, 2)
	var slot: int = -1
	for index: int in range(bag.slot_count):
		if bag.get_slot_item(index) == item:
			slot = index
			break
	return system.plant(cell, bag, slot, item, now)

func test_planting_checks_zone_spacing_occupancy_and_spends_only_one_seed() -> void:
	var apple: ItemDefinition = load("res://items/trees/apple_sapling.tres") as ItemDefinition
	assert_false(system.can_place(Vector2i(68, 61), apple.crop as TreeDefinition))
	assert_false(system.can_place(Vector2i(13, 61), apple.crop as TreeDefinition))
	var tree: PerennialTree = _plant("apple", Vector2i(12, 61))
	assert_not_null(tree)
	assert_eq(bag.count_item(&"apple_sapling"), 1)
	assert_false(system.can_place(Vector2i(12, 61), tree.definition))
	assert_eq(tree.global_position, system.point_for(Vector2i(12, 61)))

func test_uproot_frees_cell_for_replanting_and_full_timber_rewards_drop_safely() -> void:
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	assert_true(fruit.uproot(bag))
	assert_false(system.trees.has(Vector2i(12, 61)))
	await get_tree().process_frame
	assert_not_null(_plant("apple", Vector2i(12, 61)))
	var tree: TimberTree = _plant("oak", Vector2i(68, 61)) as TimberTree
	tree.refresh(1240.0)
	var full: InventoryComponent = InventoryComponent.new()
	full.slot_count = 1
	full.starting_tools = false
	add_child_autofree(full)
	full.add(load("res://items/tools/hoe.tres"), 1)
	for hit: int in range(4):
		assert_true(tree.chop(full))
	assert_true(tree.stump)
	var wood: int = 0
	var seeds: int = 0
	for child: Node in world.get_children():
		if child is ItemPickup:
			if child.item.item_id == &"wood": wood += child.amount
			if child.item.item_id == &"oak_sapling": seeds += child.amount
	assert_eq(wood, 5)
	assert_eq(seeds, 1)

func test_save_roundtrip_preserves_tree_and_stump_and_rejects_corrupt_state_first() -> void:
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	fruit.water(now)
	var timber: TimberTree = _plant("oak", Vector2i(68, 61)) as TimberTree
	now = 1240.0
	system.advance(now)
	for hit: int in range(4): timber.chop(bag)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("test", 1, now)
	assert_eq(saved.trees.size(), 2)
	var checked: Dictionary = adapter.preflight(saved)
	assert_true(checked.ok, str(checked))
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.trees[0].cell = [68, 61]
	assert_false(adapter.restore(corrupt, now).ok)
	assert_eq(system.trees.size(), 2)
	now = 1480.0
	var restored: Dictionary = adapter.restore(saved, now)
	assert_true(restored.ok, str(restored))
	assert_true((system.trees[Vector2i(12, 61)] as FruitTree).has_fruit())
	assert_false((system.trees[Vector2i(68, 61)] as TimberTree).stump)
	assert_true(system.trees[Vector2i(68, 61)].is_mature())
	assert_eq(bag.count_item(&"wood"), 5)

func test_selected_tool_routes_to_tree_with_one_impact_and_slot_change_cancels() -> void:
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	var player: FarmPlayer = world.player
	player.global_position = fruit.global_position + Vector2(0, 24)
	player.animation.facing_direction = &"up"
	player.selection.select_slot(1)
	assert_true(player.state.use_selected_tool())
	assert_eq(player.state.active_action, &"tree_water")
	player.animation.animated_sprite.frame = player.animation.animated_sprite.sprite_frames.get_frame_count(player.animation.animated_sprite.animation) - 1
	player.tree_interaction._impact()
	assert_false(fruit.can_water())
	player.state.reset_after_load()
	player.selection.select_slot(0)
	assert_true(player.state.use_selected_tool())
	assert_eq(player.state.active_action, &"tree_uproot")
	player.selection.select_slot(1)
	player.animation.animated_sprite.frame = player.animation.animated_sprite.sprite_frames.get_frame_count(player.animation.animated_sprite.animation) - 1
	player.tree_interaction._impact()
	assert_false(fruit.removed)

func test_c_harvest_keeps_mature_tree_even_when_holding_hoe() -> void:
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	fruit.water(now)
	now = 1270.0
	system.advance(now)
	var player: FarmPlayer = world.player
	player.global_position = fruit.global_position + Vector2(0, 24)
	player.animation.facing_direction = &"up"
	player.selection.select_slot(0)
	await get_tree().physics_frame
	assert_true(player.interactions.press())
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	assert_eq(bag.count_item(&"apple"), 3, "Fruit commits on input, without an animation impact")
	player.tree_interaction._impact()
	assert_false(fruit.removed)
	assert_eq(bag.count_item(&"apple"), 3)
	assert_eq(player.item_feedback._bursts.size(), 1)

func _ripe(id: String = "apple") -> FruitTree:
	var fruit: FruitTree = _plant(id, Vector2i(12, 61)) as FruitTree
	fruit.water(now)
	now += 270.0
	system.advance(now)
	return fruit

func _click_point(fruit: FruitTree) -> Vector2:
	var target: InteractionTarget = InteractionTarget.new(fruit, InteractionTarget.Kind.TREE, world.player)
	return fruit.sprite.to_global(world.player.interactions.resolver.visual_rect(target).get_center())

func test_click_ripe_fruit_with_hoe_harvests_immediately_with_one_visual_reward(id = use_parameters(["apple", "peach", "pear", "cherry"])) -> void:
	var fruit: FruitTree = _ripe(id)
	var ground_piles: int = get_tree().get_nodes_in_group(&"item_pickups").size()
	var player: FarmPlayer = world.player
	player.global_position = fruit.global_position + Vector2(0, 24)
	player.selection.select_slot(0)
	assert_eq(fruit.action_text(player.selection.get_selected_item()), tr("Harvest fruit"))
	await get_tree().physics_frame
	assert_true(player.interactions.click(_click_point(fruit)))
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	assert_false(fruit.has_fruit())
	assert_false(fruit.removed)
	assert_eq(bag.count_item(StringName(id)), 3)
	assert_eq(player.item_feedback._bursts.size(), 1)
	var burst: HarvestBurst = player.item_feedback._bursts[0]
	assert_eq(burst.item, fruit.definition.harvest_item)
	assert_eq(burst.icons.size(), 3)
	assert_gt(burst.drop_height, 0.0)
	assert_almost_eq(burst.global_position.y + burst.drop_height, fruit.global_position.y, 0.01)
	assert_eq(get_tree().get_nodes_in_group(&"item_pickups").size(), ground_piles)
	assert_true(player.interactions.click(_click_point(fruit)))
	assert_eq(player.state.current_state, StateComponent.State.IDLE, "Double click must not start uprooting")
	# Animation/feedback không phải giao dịch; chạy hết không được cộng quả lần hai.
	player.tree_interaction._impact()
	burst._process(0.8)
	await get_tree().process_frame
	assert_false(is_instance_valid(burst))
	assert_eq(bag.count_item(StringName(id)), 3)
	assert_eq(player.item_feedback._popups.size(), 1)
	assert_eq(player.item_feedback._popups[0].amount, 3)

func test_distant_click_walks_to_tree_and_harvests_only_on_arrival_without_tool_state() -> void:
	var fruit: FruitTree = _ripe()
	var player: FarmPlayer = world.player
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.global_position = fruit.global_position + Vector2(100, 24)
	player.selection.select_slot(0)
	var states: Array[StringName] = []
	player.state.state_changed.connect(func(_previous: StringName, current: StringName) -> void: states.append(current))
	await wait_physics_frames(3)
	assert_true(player.interactions.click(_click_point(fruit)))
	assert_not_null(player.interactions.pending)
	assert_eq(bag.count_item(&"apple"), 0)
	assert_true(fruit.has_fruit())
	for frame: int in range(240):
		await get_tree().physics_frame
		if bag.count_item(&"apple") > 0:
			break
	assert_eq(bag.count_item(&"apple"), 3)
	assert_lte(player.global_position.distance_to(fruit.global_position), 32.0)
	assert_null(player.interactions.pending)
	assert_false(states.has(&"tool"))
	assert_false(states.has(&"water"))
	assert_false(fruit.removed)
	await wait_seconds(0.9)
	assert_eq(bag.count_item(&"apple"), 3)

func test_full_bag_click_preserves_fruit_and_does_not_show_reward_or_swing_hoe() -> void:
	var fruit: FruitTree = _ripe()
	var player: FarmPlayer = world.player
	player.global_position = fruit.global_position + Vector2(0, 24)
	player.selection.select_slot(0)
	for slot: int in range(bag.slot_count):
		bag.add(load("res://items/tools/axe.tres"), 1)
	await get_tree().physics_frame
	assert_true(player.interactions.click(_click_point(fruit)))
	assert_true(fruit.has_fruit())
	assert_false(fruit.removed)
	assert_eq(bag.count_item(&"apple"), 0)
	assert_eq(player.item_feedback._bursts.size(), 0)
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	assert_eq(player.item_feedback._popups[0].amount, 0)

func test_bee_bonus_obeys_range_and_weather_boundaries_in_offline_catchup() -> void:
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	fruit.water(now)
	world.farming.weather.changes = [{"at":1000.0,"weather":0}, {"at":1200.0,"weather":1}, {"at":1220.0,"weather":0}]
	world.apiary.create_hive(fruit.global_position + Vector2(48, 0), &"tree_test_hive")
	now = 1240.0
	system.advance(now)
	# 20s nắng + 20s mưa + 20s nắng, sau mốc trưởng thành 1180.
	assert_almost_eq(fruit.fruit_work, 40.0 / 0.75 + 20.0, 0.0001)
	assert_false(fruit.has_fruit())
	now = 1252.5
	system.advance(now)
	assert_true(fruit.has_fruit())

func test_legacy_save_adds_empty_trees_and_current_save_rejects_invalid_tree_fields() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var legacy: Dictionary = adapter.capture("test", 1, now)
	legacy.version = 10
	legacy.erase("trees")
	var migrated: Dictionary = adapter.preflight(legacy)
	assert_true(migrated.ok, str(migrated))
	assert_eq(migrated.snapshot.trees, [])
	assert_false(legacy.has("trees"))
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	var saved: Dictionary = adapter.capture("test", 1, now)
	for patch: Dictionary in [{"fruit_work":-1}, {"fruit_work":91}, {"tree":"../../bad"}, {"last_at":1001.0}, {"matures_at":1.0}, {"growth_started_at":-0.5}, {"cell":[68,61]}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.trees[0].merge(patch, true)
		assert_false(adapter.restore(bad, now).ok, str(patch))
		assert_false(fruit.removed)
	var repeated: Dictionary = saved.duplicate(true)
	repeated.trees.append(repeated.trees[0].duplicate(true))
	assert_false(adapter.preflight(repeated).ok)

func test_shop_supplies_sell_all_tree_starters_and_axe_and_buyer_accepts_outputs() -> void:
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var ids: Array[StringName] = []
	for offer: ShopOffer in stock.offers:
		ids.append(offer.item.item_id)
	for id: StringName in [&"apple_sapling", &"peach_sapling", &"pear_sapling", &"cherry_sapling", &"oak_sapling", &"birch_sapling", &"spruce_sapling", &"axe"]:
		assert_has(ids, id)
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	var products: Array[StringName] = []
	for entry: ProducePrice in prices.entries:
		products.append(entry.item.item_id)
	for id: StringName in [&"apple", &"peach", &"pear", &"cherry", &"wood", &"root_wood"]:
		assert_has(products, id)

func test_captured_world_with_fruit_tree_uses_string_keys_and_saves_asynchronously() -> void:
	var fruit: FruitTree = _plant("apple", Vector2i(12, 61)) as FruitTree
	fruit.water(now)
	now = 1270.0
	system.advance(now)
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("test", 1, now)
	var folder: String = "res://.godot/tree_async_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(folder, catalog)
	assert_true(repository._primitive(snapshot), "Live capture must meet the async writer's primitive-only boundary")
	var written: Dictionary = await repository.write_profile_async("test", snapshot, 0)
	assert_true(written.ok, str(written))
	var loaded: Dictionary = repository.read_profile("test")
	assert_true(loaded.ok, str(loaded))
	assert_eq(loaded.snapshot.trees.size(), 1)
	assert_eq(loaded.snapshot.trees[0].fruit_work, 90.0)
