extends GutTest
## Check visible artwork, including atlas padding, against authored walking space.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: Node2D
var decor: Node2D

func before_each() -> void:
	# Inspect authored geometry without starting gameplay or loading a save.
	world = WORLD.instantiate() as Node2D
	decor = world.get_node("BuildingDecor") as Node2D

func after_each() -> void:
	world.free()

func _visible_rects() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in decor.find_children("*", "Sprite2D", true, false):
		var sprite: Sprite2D = node as Sprite2D
		var image: Image = sprite.texture.get_image()
		if sprite.region_enabled:
			image = image.get_region(Rect2i(sprite.region_rect))
		var used: Rect2 = Rect2(image.get_used_rect())
		used.position += sprite.get_rect().position
		result[str(decor.get_path_to(sprite))] = [sprite.get_global_transform() * used]
	for node: Node in decor.find_children("*", "AnimatedSprite2D", true, false):
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		var frames: Array[Rect2] = []
		for index: int in range(sprite.sprite_frames.get_frame_count(sprite.animation)):
			var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, index)
			var used: Rect2 = Rect2(texture.get_image().get_used_rect())
			used.position += sprite.offset
			if sprite.centered:
				used.position -= Vector2(texture.get_size()) / 2.0
			frames.append(sprite.get_global_transform() * used)
		result[str(decor.get_path_to(sprite))] = frames
	return result

func test_props_and_yards_do_not_cover_road_tiles() -> void:
	var road: TileMapLayer = world.get_node("Road") as TileMapLayer
	var yards: TileMapLayer = decor.get_node("ShopForecourts") as TileMapLayer
	var visuals: Dictionary = _visible_rects()
	var failures: Array[String] = []
	for cell: Vector2i in road.get_used_cells():
		var road_rect: Rect2 = Rect2(road.to_global(road.map_to_local(cell)) - Vector2(8, 8), Vector2(16, 16))
		for key: String in visuals:
			for bounds: Rect2 in visuals[key]:
				if bounds.intersects(road_rect):
					failures.append(key + " over road " + str(cell))
		var yard_cell: Vector2i = yards.local_to_map(yards.to_local(road_rect.get_center()))
		if yards.get_cell_source_id(yard_cell) != -1:
			failures.append("Yard over road " + str(cell))
	assert_eq(failures.size(), 0, str(failures))
	assert_gt(visuals.size(), 0, "The decor scene must contain visible artwork")

func test_storage_and_npc_approaches_remain_open() -> void:
	var approaches: Dictionary = {}
	for path: String in ["Warehouse/StorageAccess", "SeedInventory/StorageAccess"]:
		var access: Node2D = world.get_node(path) as Node2D
		var area: CollisionShape2D = access.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
		var size: Vector2 = (area.shape as RectangleShape2D).size
		approaches[path] = area.get_global_transform() * Rect2(-size / 2.0, size)
	for path: String in ["PetMerchant", "BlacksmithMerchant", "LaiBuon", "FlowerMerchant", "ProduceBuyer"]:
		var actor: Node2D = world.get_node(path) as Node2D
		approaches[path] = Rect2(actor.global_position + Vector2(-18, -8), Vector2(36, 40))
	var chef: ShopMerchant = world.get_node("Chef") as ShopMerchant
	approaches["Chef"] = Rect2(chef.interaction_position() + Vector2(-18, -20), Vector2(36, 40))
	var visuals: Dictionary = _visible_rects()
	var failures: Array[String] = []
	for target: String in approaches:
		for key: String in visuals:
			for bounds: Rect2 in visuals[key]:
				if bounds.intersects(approaches[target]):
					failures.append(key + " covers " + target)
	assert_eq(failures.size(), 0, str(failures))

func test_courtyard_edges_follow_the_actual_tile_boundaries() -> void:
	var yards: TileMapLayer = decor.get_node("ShopForecourts") as TileMapLayer
	var failures: Array[String] = []
	for cell: Vector2i in yards.get_used_cells():
		var expected_x: int = 1
		var expected_y: int = 1
		if yards.get_cell_source_id(cell + Vector2i.LEFT) == -1:
			expected_x = 0
		elif yards.get_cell_source_id(cell + Vector2i.RIGHT) == -1:
			expected_x = 2
		if yards.get_cell_source_id(cell + Vector2i.UP) == -1:
			expected_y = 0
		elif yards.get_cell_source_id(cell + Vector2i.DOWN) == -1:
			expected_y = 2
		# An intentional paving-to-soil entrance must not have a grass seam.
		var road: TileMapLayer = world.get_node("Road") as TileMapLayer
		var west: Vector2 = yards.to_global(yards.map_to_local(cell + Vector2i.LEFT))
		if road.get_cell_source_id(road.local_to_map(road.to_local(west))) != -1:
			expected_x = 1
		var actual: Vector2i = yards.get_cell_atlas_coords(cell)
		if actual != Vector2i(expected_x, expected_y):
			failures.append(str(cell) + " has incorrect edge " + str(actual))
		var source: TileSetAtlasSource = yards.tile_set.get_source(yards.get_cell_source_id(cell)) as TileSetAtlasSource
		assert_not_null(source.texture, "Courtyard texture is present")
		var image: Image = source.texture.get_image()
		assert_false(image.get_region(Rect2i(actual * 16, Vector2i(16,16))).get_used_rect().size == Vector2i.ZERO, "Tile artwork is not empty")
	assert_eq(failures.size(), 0, str(failures))
