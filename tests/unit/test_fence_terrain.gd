extends GutTest

const FENCES: TileSet = preload("res://resources/tilesets/fence.tres")
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SIDES: Array[int] = [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
const OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func test_fence_layer_uses_four_named_terrains_without_white_fence() -> void:
	var world: Node = WORLD.instantiate()
	assert_eq(world.get_node("Fence").tile_set, FENCES)
	assert_eq(FENCES.get_terrain_sets_count(), 1)
	assert_eq(FENCES.get_terrain_set_mode(0), TileSet.TERRAIN_MODE_MATCH_SIDES)
	assert_eq(FENCES.get_terrains_count(0), 4)
	var expected: Array[String] = ["Hàng rào gỗ", "Hàng rào gỗ lớn", "Hàng rào đá nhỏ", "Hàng rào đá lớn"]
	for terrain: int in range(4):
		assert_eq(FENCES.get_terrain_name(0, terrain), expected[terrain])
	assert_eq(FENCES.get_source_count(), 4)
	for index: int in range(FENCES.get_source_count()):
		var source: TileSetAtlasSource = FENCES.get_source(FENCES.get_source_id(index)) as TileSetAtlasSource
		assert_false(source.texture.resource_path.contains("White_Fence"))
	world.free()

func test_all_sixteen_neighbour_patterns_autoconnect(terrain = use_parameters([0, 1, 2, 3])) -> void:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = FENCES
	add_child_autofree(layer)
	for mask: int in range(16):
		layer.clear()
		var cells: Array[Vector2i] = [Vector2i.ZERO]
		for side: int in range(4):
			if mask & (1 << side):
				cells.append(OFFSETS[side])
		layer.set_cells_terrain_connect(cells, 0, terrain, false)
		assert_eq(layer.get_used_cells().size(), cells.size(), "No holes or extra cells for mask " + str(mask))
		for cell: Vector2i in cells:
			assert_eq(layer.get_cell_source_id(cell), terrain)
		var data: TileData = layer.get_cell_tile_data(Vector2i.ZERO)
		assert_not_null(data)
		if data == null:
			continue
		assert_eq(data.terrain, terrain)
		for side: int in range(4):
			assert_eq(data.get_terrain_peering_bit(SIDES[side]), terrain if mask & (1 << side) else -1)

func test_incremental_paint_joins_and_erasing_reconnects(terrain = use_parameters([0, 1, 2, 3])) -> void:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = FENCES
	add_child_autofree(layer)
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	for cell: Vector2i in cells:
		layer.set_cells_terrain_connect([cell], 0, terrain, false)
	assert_eq(layer.get_cell_tile_data(Vector2i.RIGHT).get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE), terrain)
	assert_eq(layer.get_cell_tile_data(Vector2i.RIGHT).get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE), terrain)
	var corner: TileData = layer.get_cell_tile_data(Vector2i(2, 0))
	assert_eq(corner.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE), terrain)
	assert_eq(corner.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE), terrain)
	layer.set_cells_terrain_connect([Vector2i(2, 1)], 0, -1, false)
	assert_eq(layer.get_cell_source_id(Vector2i(2, 1)), -1)
	assert_eq(layer.get_cell_tile_data(Vector2i(2, 0)).get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE), -1)
	assert_eq(layer.get_cell_tile_data(Vector2i(2, 2)).get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE), -1)

func test_fence_physics_layer_and_collision_polygons() -> void:
	assert_eq(FENCES.get_physics_layers_count(), 1, "Fences tileset must have 1 physics layer")
	assert_eq(FENCES.get_physics_layer_collision_layer(0), 1, "Physics layer 0 collision_layer must be 1 (World)")
	var reference: TileSetAtlasSource = FENCES.get_source(1) as TileSetAtlasSource
	for index: int in range(FENCES.get_source_count()):
		var source: TileSetAtlasSource = FENCES.get_source(FENCES.get_source_id(index)) as TileSetAtlasSource
		assert_eq(source.get_tiles_count(), 16)
		for t: int in range(source.get_tiles_count()):
			var coords: Vector2i = source.get_tile_id(t)
			var data: TileData = source.get_tile_data(coords, 0)
			assert_not_null(data)
			if data != null:
				assert_eq(data.get_collision_polygons_count(0), 1, "Tile at %s must have 1 collision polygon" % str(coords))
				var expected: TileData = reference.get_tile_data(coords, 0)
				assert_eq(data.y_sort_origin, expected.y_sort_origin, "Y-sort origin at %s" % str(coords))
				assert_eq(data.get_collision_polygon_points(0, 0), expected.get_collision_polygon_points(0, 0), "Collision at %s" % str(coords))
				assert_eq(data.is_collision_polygon_one_way(0, 0), expected.is_collision_polygon_one_way(0, 0))
				assert_eq(data.get_collision_polygon_one_way_margin(0, 0), expected.get_collision_polygon_one_way_margin(0, 0))

	# Verify functional collision with a CharacterBody2D on collision_mask 1
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = FENCES
	add_child_autofree(layer)
	layer.set_cell(Vector2i(2, 2), 0, Vector2i(2, 0))

	var body: CharacterBody2D = CharacterBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(10, 4)
	col.shape = rect
	body.add_child(col)
	add_child_autofree(body)

	body.position = Vector2(20, 45)
	await wait_physics_frames(2)
	body.velocity = Vector2(100, 0)
	for i in range(10):
		body.move_and_slide()

	assert_gt(body.get_slide_collision_count(), 0, "CharacterBody2D should collide with fence layer")
	assert_lt(body.position.x, 32.0, "CharacterBody2D should be blocked by fence bounds")


