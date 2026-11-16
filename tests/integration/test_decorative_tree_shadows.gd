extends GutTest

func test_shadows_are_above_flower_beds_and_below_painted_tree_art() -> void:
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	var shadows: Node2D = world.get_node("DecorativeTreeShadows") as Node2D
	assert_eq(shadows.z_index, 0, "Flower beds at z=-1 must not cover the shadows")
	assert_lt(shadows.get_index(), world.get_node("Tree").get_index(), "Paint tree trunks after ground shadows")
	world.free()

func test_picnic_and_west_grove_trees_all_have_ground_shadows() -> void:
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	var shadows: Node2D = world.get_node("DecorativeTreeShadows") as Node2D
	var anchors: Dictionary = {}
	for child: Node in shadows.get_children():
		anchors[str(child.get_meta("tree_anchor"))] = child
	for path: String in [
		"MeadowRestDetails/PicnicOak/Crown",
		"MeadowRestDetails/PicnicWillow/Crown",
		"MeadowRestDetails/PicnicBirch/Crown",
		"MeadowRestDetails/WestGroveOak/Crown",
		"MeadowRestDetails/WestGroveWillow/Crown",
		"MeadowRestDetails/WestGroveBirch/Crown",
		"EastMeadowDecor/MeadowOak/Crown",
		"EastMeadowDecor/SouthShade/Crown"
	]:
		assert_true(anchors.has(path), path + " needs its own ground shadow")
		if anchors.has(path):
			var crown: Sprite2D = world.get_node(path) as Sprite2D
			var shadow: Sprite2D = anchors[path] as Sprite2D
			var foot: Vector2 = shadow.get_meta("visible_root")
			assert_lt(foot.distance_to((crown.get_parent() as Node2D).global_position), 3.0, "Root anchor stays at the trunk")
	world.free()

func test_all_painted_oak_style_tree_cells_are_covered() -> void:
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	var shadows: Node2D = world.get_node("DecorativeTreeShadows") as Node2D
	var anchors: Dictionary = {}
	for child: Node in shadows.get_children():
		var anchor: String = str(child.get_meta("tree_anchor"))
		assert_false(anchors.has(anchor), "Never duplicate a shadow for the same tree")
		anchors[anchor] = true
	var trees: TileMapLayer = world.get_node("Tree") as TileMapLayer
	for cell: Vector2i in trees.get_used_cells():
		var source: TileSetAtlasSource = trees.tile_set.get_source(trees.get_cell_source_id(cell)) as TileSetAtlasSource
		if source != null and source.texture.resource_path.contains("/Trees/OakStyle/"):
			assert_true(anchors.has("Tree@%d,%d" % [cell.x, cell.y]), "Painted tree needs a matching shadow")
	world.free()
