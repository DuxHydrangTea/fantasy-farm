extends GutTest

func _tree(definition: TreeDefinition) -> TimberTree:
	var tree: TimberTree = TimberTree.new()
	tree.definition = definition
	tree.initialize(0.0)
	add_child_autofree(tree)
	return tree

func test_shadow_uses_big_oak_opacity_and_extends_below_tall_tree_roots() -> void:
	var definition: TreeDefinition = load("res://trees/definitions/blue_conifer.tres") as TreeDefinition
	assert_not_null(definition.ground_shadow_texture)
	var image: Image = definition.ground_shadow_texture.get_image()
	var seen_shadow: bool = false
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				seen_shadow = true
				assert_eq(pixel.to_rgba32(), Color8(0, 0, 0, 40).to_rgba32())
	assert_true(seen_shadow)
	assert_gt(definition.ground_shadow_offset.y + image.get_height() * 0.5, 0.0, "Full shadow can extend below the 64x80 tree frame without clipping")

func test_shadow_tracks_growth_and_stump_without_moving_the_tree() -> void:
	var definition: TreeDefinition = load("res://trees/definitions/blue_conifer.tres") as TreeDefinition
	var baseline_definition: TreeDefinition = definition.duplicate() as TreeDefinition
	baseline_definition.ground_shadow_texture = null
	var tree: TimberTree = _tree(definition)
	var baseline: TimberTree = _tree(baseline_definition)
	assert_null(tree.ground_shadow, "Sapling keeps its existing baked shadow")
	tree.refresh(definition.growth_seconds * 0.75)
	assert_null(tree.ground_shadow, "Growing tree must not receive a second shadow")
	tree.refresh(definition.growth_seconds + 1.0)
	baseline.refresh(definition.growth_seconds + 1.0)
	assert_not_null(tree.ground_shadow)
	if tree.ground_shadow == null:
		return
	assert_true(tree.ground_shadow.visible)
	assert_eq(tree.ground_shadow.get_parent(), tree, "Shadow stays outside the moving canopy node")
	assert_lt(tree.ground_shadow.z_index, tree.sprite.z_index)
	assert_eq(tree.sprite.position, baseline.sprite.position, "Adding shadow must not move the root anchor")
	assert_eq(tree.trunk.position, baseline.trunk.position)
	assert_eq(tree.sprite.texture, baseline.sprite.texture)
	tree.stump = true
	tree.update_visual()
	assert_false(tree.ground_shadow.visible, "Stump uses its original small baked shadow")
	assert_eq(tree.sprite.texture, definition.stump_texture)
	tree.stump = false
	tree.stage = 0
	tree.update_visual()
	assert_false(tree.ground_shadow.visible)
	tree.stage = 2
	tree.update_visual()
	assert_true(tree.ground_shadow.visible)

func test_existing_oak_does_not_get_a_duplicate_shadow() -> void:
	var definition: TreeDefinition = load("res://trees/definitions/oak.tres") as TreeDefinition
	assert_null(definition.ground_shadow_texture)
	var tree: TimberTree = _tree(definition)
	tree.refresh(definition.growth_seconds + 1.0)
	assert_null(tree.ground_shadow)
