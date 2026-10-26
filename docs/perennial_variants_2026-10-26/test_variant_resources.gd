extends GutTest

func test_variants_load_with_unique_ids_mature_art_and_brown_stump() -> void:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/perennial_variants_2026-10-26/manifest.json")) as Array
	var ids: Dictionary = {}
	var stump: Texture2D = load("res://trees/textures/oak_stump.tres") as Texture2D
	for record: Dictionary in records:
		var definition: TreeDefinition = load("res://" + str(record.definition)) as TreeDefinition
		assert_not_null(definition, str(record.tree_id))
		assert_true(definition.is_valid(), str(record.tree_id))
		assert_false(ids.has(definition.tree_id))
		ids[definition.tree_id] = true
		assert_eq(definition.planting_item().crop, definition)
		assert_eq(definition.ready_texture.resource_path, "res://" + str(record.mature_texture))
		assert_eq(definition.ready_texture.get_size(), Vector2(64, 80))
		assert_eq(definition.stage_textures[2], definition.ready_texture)
		assert_eq(definition.stump_texture, stump)
		assert_ne(definition.tree_id, &"green_birch")
	assert_eq(ids.size(), 14)

func test_all_new_variants_grow_chop_to_brown_stump_and_regrow() -> void:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/perennial_variants_2026-10-26/manifest.json")) as Array
	for record: Dictionary in records:
		var definition: TreeDefinition = load("res://" + str(record.definition)) as TreeDefinition
		var bag: InventoryComponent = InventoryComponent.new()
		bag.starting_tools = false
		bag.slot_count = 8
		add_child(bag)
		var tree: TimberTree = TimberTree.new()
		tree.definition = definition
		tree.initialize(1000.0)
		add_child(tree)
		assert_eq(tree.sprite.texture, definition.stage_textures[0])
		tree.refresh(1000.0 + definition.growth_seconds)
		assert_true(tree.is_mature())
		assert_eq(tree.sprite.texture, definition.ready_texture)
		for hit: int in range(definition.chop_hits):
			assert_true(tree.chop(bag))
		assert_true(tree.stump)
		assert_eq(tree.sprite.texture, definition.stump_texture)
		assert_null(tree.sprite.material)
		assert_eq(tree.capture().tree, str(definition.tree_id))
		tree.refresh(tree.regrow_at)
		assert_false(tree.stump)
		assert_eq(tree.sprite.texture, definition.stage_textures[0])
		tree.free()
		bag.free()
