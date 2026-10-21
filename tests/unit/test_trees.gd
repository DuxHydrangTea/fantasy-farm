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
	for id: String in ["apple", "peach", "pear", "cherry", "oak", "birch", "spruce"]:
		var path: String = "res://trees/definitions/%s.tres" % id
		var definition: TreeDefinition = load(path) as TreeDefinition
		assert_true(definition.is_valid(), id)
		assert_eq(definition.planting_item().crop, definition)
		assert_eq(definition.stage_textures.size(), 3)
		if definition.kind == TreeDefinition.Kind.TIMBER:
			var ready: AtlasTexture = definition.ready_texture as AtlasTexture
			assert_eq(ready.region.position.x, ready.region.size.x)
			assert_eq((definition.stump_texture as AtlasTexture).region.position.x, 0.0)
			assert_eq((definition.canopy_texture as AtlasTexture).region.position.x, ready.region.size.x * 2)
	# Ô đầu là nho; các loại cây hiện tại chỉ dùng bốn ô còn lại.
	var fruit_columns: Dictionary = {"apple":1, "peach":3, "pear":2, "cherry":4}
	for id: String in fruit_columns:
		var path: String = "res://items/trees/%s.tres" % id
		var item: ItemDefinition = load(path) as ItemDefinition
		assert_eq((item.icon as AtlasTexture).region.position.x, float(fruit_columns[id] * 16))

func test_fruit_needs_one_watering_and_ignores_repeated_water_and_clock_reversal() -> void:
	fruit.refresh(1100.0)
	assert_true(fruit.can_water())
	assert_eq(fruit.stage, 0)
	assert_true(fruit.water(1100.0))
	assert_false(fruit.water(1110.0))
	fruit.refresh(1190.0)
	assert_eq(fruit.stage, 1)
	fruit.refresh(900.0)
	assert_eq(fruit.stage, 1)
	fruit.refresh(1280.0)
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
	fruit.refresh(1270.0)
	assert_not_null(fruit.sprite.material)
	assert_eq(fruit.sprite.texture, fruit.definition.ready_texture)
	assert_almost_eq(float((fruit.sprite.material as ShaderMaterial).get_shader_parameter(&"ground_y")) + fruit.sprite.position.y, 0.0, 0.0001)

func test_stump_stops_wind_and_regrowth_reuses_shared_sapling_material() -> void:
	var sapling_wind: Material = timber.sprite.material
	_make_stump()
	assert_null(timber.sprite.material)
	timber.refresh(1360.0)
	assert_false(timber.stump)
	assert_eq(timber.sprite.material, sapling_wind)
	var sibling: TimberTree = TimberTree.new()
	sibling.definition = timber.definition
	sibling.initialize(1000.0)
	add_child_autofree(sibling)
	assert_eq(sibling.sprite.material, timber.sprite.material, "Trees share materials instead of allocating one per planted instance")

func test_repeated_harvest_keeps_same_tree_and_does_not_bank_offline_cycles() -> void:
	fruit.water(1000.0)
	fruit.refresh(1000000.0)
	assert_true(fruit.harvest(bag))
	assert_false(fruit.harvest(bag))
	assert_false(fruit.removed)
	assert_false(fruit.is_queued_for_deletion())
	assert_eq(fruit.stage, 2)
	assert_eq(fruit.sprite.texture, fruit.definition.stage_textures[2])
	fruit.refresh(1000090.0)
	assert_true(fruit.harvest(bag))
	assert_eq(bag.count_item(&"apple"), 6)

func test_full_bag_preserves_fruit_and_uproot_then_returns_one_sapling() -> void:
	bag.slot_count = 8
	for index: int in range(8):
		bag.add(load("res://items/tools/axe.tres"), 1)
	fruit.water(1000.0)
	fruit.refresh(1300.0)
	assert_false(fruit.harvest(bag))
	assert_true(fruit.has_fruit())
	assert_false(fruit.uproot(bag))
	assert_false(fruit.removed)
	bag.remove(&"axe", 1)
	assert_true(fruit.uproot(bag))
	assert_eq(bag.count_item(&"apple_sapling"), 1)
	assert_false(fruit.uproot(bag))

func test_reentrant_inventory_signal_cannot_harvest_twice() -> void:
	fruit.water(1000.0)
	fruit.refresh(1300.0)
	bag.changed.connect(func() -> void: fruit.harvest(bag))
	assert_true(fruit.harvest(bag))
	assert_eq(bag.count_item(&"apple"), 3)

func test_pollination_shortens_only_fruit_cycle_by_25_percent() -> void:
	fruit.water(1000.0)
	fruit.refresh(1180.0)
	fruit.refresh(1247.5, 1.0 / 0.75)
	assert_true(fruit.has_fruit())
	assert_eq(fruit.matures_at, 1180.0)

func test_timestamp_roundtrip_resumes_remaining_fruit_without_duplicate_work() -> void:
	fruit.water(1000.0)
	fruit.refresh(1200.0)
	var row: Dictionary = fruit.capture()
	var restored: FruitTree = FruitTree.new()
	restored.definition = fruit.definition
	add_child_autofree(restored)
	restored.restore_state(row)
	restored.refresh(1270.0)
	assert_true(restored.has_fruit())
	assert_eq(restored.fruit_work, 90.0)
	restored.refresh(1200.0)
	assert_eq(restored.last_at, 1270.0)

func test_timber_rejects_immature_chop_then_keeps_solid_stump_after_four_hits() -> void:
	assert_false(timber.chop(bag))
	timber.refresh(1240.0)
	for index: int in range(3):
		assert_true(timber.chop(bag))
		assert_false(timber.stump)
	assert_true(timber.chop(bag))
	assert_true(timber.stump)
	assert_false(timber.chop(bag))
	assert_false(timber.trunk.disabled)
	assert_eq((timber.trunk.shape as RectangleShape2D).size, Vector2(15, 6))
	assert_eq(bag.count_item(&"wood"), 5)
	assert_eq(bag.count_item(&"oak_sapling"), 1)
	assert_eq(timber.sprite.texture, timber.definition.stump_texture)

func test_stump_requires_three_digs_and_yields_roots_once() -> void:
	_make_stump()
	assert_true(timber.dig(bag))
	assert_true(timber.dig(bag))
	assert_false(timber.removed)
	assert_true(timber.dig(bag))
	assert_true(timber.removed)
	assert_false(timber.dig(bag))
	assert_eq(bag.count_item(&"root_wood"), 2)

func test_stump_regrows_automatically_in_half_the_original_growth_time() -> void:
	_make_stump()
	var row: Dictionary = timber.capture()
	var restored: TimberTree = TimberTree.new()
	restored.definition = timber.definition
	add_child_autofree(restored)
	restored.restore_state(row)
	restored.refresh(1360.0)
	assert_false(restored.stump)
	assert_false(restored.is_mature())
	assert_eq(restored.hits, 0)
	assert_eq(restored.matures_at, 1480.0)
	restored.refresh(1480.0)
	assert_true(restored.is_mature())
	assert_eq(bag.count_item(&"wood"), 5)

func test_partial_chops_and_partial_digs_survive_restore_without_extra_rewards() -> void:
	timber.refresh(1240.0)
	timber.chop(bag)
	timber.chop(bag)
	var row: Dictionary = timber.capture()
	timber.restore_state(row)
	timber.chop(bag)
	assert_false(timber.stump)
	timber.chop(bag)
	assert_eq(bag.count_item(&"wood"), 5)
	timber.dig(bag)
	timber.dig(bag)
	timber.restore_state(timber.capture())
	timber.dig(bag)
	assert_eq(bag.count_item(&"root_wood"), 2)

func _make_stump() -> void:
	timber.refresh(1240.0)
	for index: int in range(4):
		timber.chop(bag)
