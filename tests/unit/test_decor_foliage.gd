extends GutTest
const HELPER = preload("res://components/grass/decor_foliage_materials.gd")
const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_nested_decor_is_covered_without_animating_props_or_changing_placement() -> void:
	var world: Node2D = WORLD.instantiate() as Node2D
	var helper: RefCounted = HELPER.new()
	var flower: Sprite2D = world.get_node("EastMeadowDecor/MeadowFlower000") as Sprite2D
	var tree: Sprite2D = world.get_node("EastMeadowDecor/NorthOak/Crown") as Sprite2D
	var rock: Sprite2D = world.get_node("EastMeadowDecor/BorderRock0/Rock") as Sprite2D
	var blanket: Sprite2D = world.get_node("MeadowRestDetails/PicnicBlanket") as Sprite2D
	var pose: Transform2D = flower.transform
	var original_tiles: TileSet = (world.get_node("Tree") as TileMapLayer).tile_set
	helper.install(world, world.get_node("TinyDecor"))
	assert_gt(helper.sprite_count, 0)
	for path: String in ["CoopGardenDecor", "BarnGardenDecor", "RiversideRest", "EastMeadowDecor", "MeadowRestDetails"]:
		var covered: bool = false
		for node: Node in world.get_node(path).find_children("*", "Sprite2D", true, false):
			if node.material is ShaderMaterial and node.material.shader == HELPER.SHADER:
				covered = true
		assert_true(covered, path + " has interactive foliage")
	assert_gt(helper.tile_count, 0, "Decorative foliage TileMaps also participate")
	assert_true(flower.material is ShaderMaterial)
	assert_true(tree.material is ShaderMaterial)
	assert_null(rock.material, "Rocks remain rigid")
	assert_null(blanket.material, "Picnic props remain rigid")
	assert_eq(flower.transform, pose, "No transform/pivot or placement changes")
	assert_ne((world.get_node("Tree") as TileMapLayer).tile_set, original_tiles)
	helper.restore()
	assert_null(flower.material)
	assert_null(tree.material)
	assert_eq((world.get_node("Tree") as TileMapLayer).tile_set, original_tiles)
	helper.restore()
	world.free()

func test_shared_materials_respect_frames_flips_and_existing_art_materials() -> void:
	var root: Node2D = Node2D.new()
	var sprites: Array[Sprite2D] = []
	for index: int in range(4):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load("res://assets/Trees/Medium_Oak_Tree.png") as Texture2D
		sprite.hframes = 3
		sprite.frame = 1
		root.add_child(sprite)
		sprites.append(sprite)
	sprites[2].flip_h = true
	var existing: ShaderMaterial = load("res://resources/effects/crop_wind.tres") as ShaderMaterial
	sprites[3].material = existing
	var helper: RefCounted = HELPER.new()
	helper.install(root)
	assert_eq(helper.materials.size(), 2, "One material per atlas region/flip, not per sprite")
	assert_eq(sprites[0].material, sprites[1].material)
	assert_eq((sprites[0].material as ShaderMaterial).get_shader_parameter(&"source_pixel"), Vector2(32, 0))
	assert_eq((sprites[2].material as ShaderMaterial).get_shader_parameter(&"uv_axis"), Vector2(-1, 1))
	assert_eq(sprites[3].material, existing, "Existing art effects are preserved")
	var effect: ShaderMaterial = ShaderMaterial.new()
	effect.shader = load("res://shaders/grass_farm.gdshader") as Shader
	effect.set_shader_parameter(&"actor_count", 1)
	effect.set_shader_parameter(&"wind_strength", 2.8)
	helper.sync_from(effect)
	for material: ShaderMaterial in helper.materials:
		assert_eq(material.get_shader_parameter(&"actor_count"), 1)
		assert_eq(material.get_shader_parameter(&"wind_strength"), 2.8)
	sprites[0].material = existing
	helper.restore()
	assert_eq(sprites[0].material, existing, "Restore preserves later external material edits")
	assert_null(sprites[1].material)
	root.free()
