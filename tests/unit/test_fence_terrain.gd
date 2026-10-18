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
