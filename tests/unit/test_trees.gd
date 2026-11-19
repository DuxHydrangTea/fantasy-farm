extends GutTest
var bag: InventoryComponent
var fruit: FruitTree
var timber: TimberTree

func before_each() -> void:
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 8
	add_child_autofree(bag)
	fruit = FruitTree.new()
	fruit.definition = load("res://trees/definitions/apple.tres") as TreeDefinition
	fruit.initialize(1000.0)
	add_child_autofree(fruit)
	timber = TimberTree.new()
	timber.definition = load("res://trees/definitions/oak.tres") as TreeDefinition
	timber.initialize(1000.0)
	add_child_autofree(timber)

func test_all_definitions_use_the_shipped_atlases_and_noncyclic_planting_items() -> void:
	var expected_prices: Dictionary = {"apple": 20000, "peach": 20000, "pear": 25000, "cherry": 30000}
	for id: String in ["apple", "peach", "pear", "cherry", "oak", "birch", "spruce"]:
		var path: String = "res://trees/definitions/%s.tres" % id
		var definition: TreeDefinition = load(path) as TreeDefinition
		assert_true(definition.is_valid(), id)
		assert_eq(definition.price, int(expected_prices.get(id, 25000)), id)
		assert_eq(definition.planting_item().crop, definition)
		assert_eq(definition.stage_textures.size(), 3)
		if definition.kind == TreeDefinition.Kind.TIMBER:
			var ready: AtlasTexture = definition.ready_texture as AtlasTexture
			assert_eq(ready.region.position.x, ready.region.size.x)
			assert_eq((definition.stump_texture as AtlasTexture).region.position.x, 0.0)
			assert_eq((definition.canopy_texture as AtlasTexture).region.position.x, ready.region.size.x * 2)
	for file: String in ResourceLoader.list_directory("res://trees/definitions"):
		if file.ends_with(".tres"):
			var definition: TreeDefinition = load("res://trees/definitions/" + file) as TreeDefinition
			assert_true(definition.is_valid(), file)
			assert_gt(definition.price, 0, file)
	for id: String in ["apple", "peach", "pear", "cherry"]:
		var path: String = "res://items/trees/%s.tres" % id
		var item: ItemDefinition = load(path) as ItemDefinition
		assert_not_null(item.icon, id)
		assert_eq(item.item_id, StringName(id), id)

func test_fruit_needs_one_watering_and_ignores_repeated_water_and_clock_reversal() -> void:
	var growth: float = fruit.definition.growth_seconds
	fruit.refresh(1100.0)
	assert_true(fruit.can_water())
	assert_eq(fruit.stage, 0)
	assert_true(fruit.water(1100.0))
	assert_false(fruit.water(1110.0))
	fruit.refresh(1100.0 + growth * 0.5)
	assert_eq(fruit.stage, 1)
	fruit.refresh(900.0)
	assert_eq(fruit.stage, 1)
	fruit.refresh(1100.0 + growth)
	assert_true(fruit.is_mature())
	assert_false(fruit.can_water())
	assert_false(fruit.has_fruit())

func test_wind_pins_visible_root_at_every_stage_and_keeps_collider_unchanged() -> void:
	var original_trunk: Transform2D = timber.trunk.transform
	var original_body: Transform2D = timber.transform
	for texture: Texture2D in timber.definition.stage_textures:
		timber.set_texture(texture)
		var wind: ShaderMaterial = timber.sprite.material as ShaderMaterial
		assert_not_null(wind)
		assert_true(bool(wind.get_shader_parameter(&"anchor_visible_root")))
		assert_almost_eq(float(wind.get_shader_parameter(&"ground_y")) + timber.sprite.position.y, 0.0, 0.0001)
		assert_gt(float(wind.get_shader_parameter(&"amplitude")), 0.0)
		assert_eq(timber.trunk.transform, original_trunk)
		assert_eq(timber.transform, original_body)
	fruit.water(1000.0)
	fruit.refresh(1000.0 + fruit.definition.growth_seconds + fruit.definition.fruit_cycle_seconds)
	assert_not_null(fruit.sprite.material)
	assert_eq(fruit.sprite.texture, fruit.definition.ready_texture)
	assert_almost_eq(float((fruit.sprite.material as ShaderMaterial).get_shader_parameter(&"ground_y")) + fruit.sprite.position.y, 0.0, 0.0001)

func test_stump_stops_wind_and_regrowth_reuses_shared_sapling_material() -> void:
	var sapling_wind: Material = timber.sprite.material
	_make_stump()
	assert_null(timber.sprite.material)
	timber.refresh(timber.regrow_at)
	assert_false(timber.stump)
	assert_eq(timber.sprite.material, sapling_wind)
	var sibling: TimberTree = TimberTree.new()
	sibling.definition = timber.definition
	sibling.initialize(1000.0)
	add_child_autofree(sibling)
	assert_eq(sibling.sprite.material, timber.sprite.material, "Trees share materials instead of allocating one per planted instance")

func test_repeated_harvest_keeps_same_tree_and_does_not_bank_offline_cycles() -> void:
	var amount: int = fruit.definition.harvest_amount
	fruit.water(1000.0)
	fruit.refresh(1000000.0)
	assert_true(fruit.harvest(bag))
	assert_false(fruit.harvest(bag))
	assert_false(fruit.removed)
	assert_false(fruit.is_queued_for_deletion())
	assert_eq(fruit.stage, 2)
	assert_eq(fruit.sprite.texture, fruit.definition.stage_textures[2])
	fruit.refresh(1000000.0 + fruit.definition.fruit_cycle_seconds)
	assert_true(fruit.harvest(bag))
	assert_eq(bag.count_item(&"apple"), amount * 2)

func test_full_bag_preserves_fruit_and_uproot_succeeds_without_returning_saplings() -> void:
	bag.slot_count = 8
	for index: int in range(8):
		bag.add(load("res://items/tools/axe.tres"), 1)
	fruit.water(1000.0)
	fruit.refresh(1000.0 + fruit.definition.growth_seconds + fruit.definition.fruit_cycle_seconds)
	assert_false(fruit.harvest(bag))
	assert_true(fruit.has_fruit())
	assert_true(fruit.uproot(bag))
	assert_true(fruit.removed)
	assert_eq(bag.count_item(&"apple_sapling"), 0)
	assert_false(fruit.uproot(bag))
	assert_true(timber.uproot(bag))
	assert_true(timber.removed)
	assert_eq(bag.count_item(&"oak_sapling"), 0)
	assert_false(timber.uproot(bag))

func test_reentrant_inventory_signal_cannot_harvest_twice() -> void:
	fruit.water(1000.0)
	fruit.refresh(1000.0 + fruit.definition.growth_seconds + fruit.definition.fruit_cycle_seconds)
	bag.changed.connect(func() -> void: fruit.harvest(bag))
	assert_true(fruit.harvest(bag))
	assert_eq(bag.count_item(&"apple"), fruit.definition.harvest_amount)

func test_pollination_shortens_only_fruit_cycle_by_25_percent() -> void:
	var mature_at: float = 1000.0 + fruit.definition.growth_seconds
	fruit.water(1000.0)
	fruit.refresh(mature_at)
	fruit.refresh(mature_at + fruit.definition.fruit_cycle_seconds * 0.75, 1.0 / 0.75)
	assert_true(fruit.has_fruit())
	assert_eq(fruit.matures_at, mature_at)

func test_timestamp_roundtrip_resumes_remaining_fruit_without_duplicate_work() -> void:
	var mature_at: float = 1000.0 + fruit.definition.growth_seconds
	var cycle: float = fruit.definition.fruit_cycle_seconds
	fruit.water(1000.0)
	fruit.refresh(mature_at + cycle * 0.5)
	var row: Dictionary = fruit.capture()
	var restored: FruitTree = FruitTree.new()
	restored.definition = fruit.definition
	add_child_autofree(restored)
	restored.restore_state(row)
	restored.refresh(mature_at + cycle)
	assert_true(restored.has_fruit())
	assert_almost_eq(restored.fruit_work, cycle, 0.001)
	restored.refresh(mature_at + cycle * 0.5)
	assert_eq(restored.last_at, mature_at + cycle)

func test_timber_rejects_immature_chop_then_keeps_solid_stump_without_sapling_drop() -> void:
	assert_false(timber.chop(bag))
	timber.refresh(1000.0 + timber.definition.growth_seconds)
	for index: int in range(timber.definition.chop_hits - 1):
		assert_true(timber.chop(bag))
		assert_false(timber.stump)
	assert_true(timber.chop(bag))
	assert_true(timber.stump)
	assert_false(timber.chop(bag))
	assert_false(timber.trunk.disabled)
	assert_eq((timber.trunk.shape as RectangleShape2D).size, Vector2(15, 6))
	assert_eq(bag.count_item(&"wood"), timber.definition.harvest_amount)
	assert_eq(bag.count_item(&"oak_sapling"), 0)
	assert_eq(timber.sprite.texture, timber.definition.stump_texture)

func test_stump_requires_dig_hits_and_yields_roots_once() -> void:
	_make_stump()
	for index: int in range(timber.definition.dig_hits - 1):
		assert_true(timber.dig(bag))
		assert_false(timber.removed)
	assert_true(timber.dig(bag))
	assert_true(timber.removed)
	assert_false(timber.dig(bag))
	assert_eq(bag.count_item(&"root_wood"), 2)

func test_stump_regrows_automatically_in_half_the_original_growth_time() -> void:
	_make_stump()
	var regrow_at: float = timber.regrow_at
	var row: Dictionary = timber.capture()
	var restored: TimberTree = TimberTree.new()
	restored.definition = timber.definition
	add_child_autofree(restored)
	restored.restore_state(row)
	restored.refresh(regrow_at)
	assert_false(restored.stump)
	assert_false(restored.is_mature())
	assert_eq(restored.hits, 0)
	assert_eq(restored.matures_at, regrow_at + timber.definition.growth_seconds * 0.5)
	restored.refresh(restored.matures_at)
	assert_true(restored.is_mature())
	assert_eq(bag.count_item(&"wood"), timber.definition.harvest_amount)
	assert_eq(bag.count_item(&"oak_sapling"), 0)

func test_partial_chops_and_partial_digs_survive_restore_without_extra_rewards() -> void:
	timber.refresh(1000.0 + timber.definition.growth_seconds)
	timber.chop(bag)
	timber.chop(bag)
	var row: Dictionary = timber.capture()
	timber.restore_state(row)
	for index: int in range(timber.definition.chop_hits - 2):
		timber.chop(bag)
	assert_true(timber.stump)
	assert_eq(bag.count_item(&"wood"), timber.definition.harvest_amount)
	assert_eq(bag.count_item(&"oak_sapling"), 0)
	timber.restore_state(timber.capture())
	for index: int in range(timber.definition.dig_hits):
		timber.dig(bag)
	assert_true(timber.removed)
	assert_eq(bag.count_item(&"root_wood"), 2)

func _make_stump() -> void:
	timber.refresh(1000.0 + timber.definition.growth_seconds)
	for index: int in range(timber.definition.chop_hits):
		timber.chop(bag)
