extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var repo: RefCounted = load("res://persistence/local_save_repository.gd").new()
	var saved: Dictionary = repo.read_profile("local")
	assert(saved.ok)
	var field: Node2D = load("res://tests/support/farming_fixture.gd").create_field()
	root.add_child(field)
	var farm: Node = field.get_node("FarmingController")
	for row: Dictionary in saved.snapshot.soil:
		load("res://tests/support/farming_fixture.gd").mark_cell(field, Vector2i(row.cell[0], row.cell[1]))
	farm.restore_soil(saved.snapshot.soil)
	var paths: TileMapLayer = field.get_node("FieldBoundaries")
	for cell: Vector2i in paths.get_used_cells():
		assert(farm.get_soil_state(cell) == 0)
	farm.rain_water()
	for cell: Vector2i in paths.get_used_cells():
		assert(farm.get_soil_state(cell) == 0)
	print("PASS: restore and rain keep all 299 path tiles untilled")
	var report: Dictionary = {}
	for layer_name: String in ["DrySoil", "WetSoil"]:
		var layer: TileMapLayer = field.get_node(layer_name)
		var bad: int = 0
		var checks: int = 0
		for cell: Vector2i in layer.get_used_cells():
			var tile: TileData = layer.get_cell_tile_data(cell)
			for pair: Array in [[TileSet.CELL_NEIGHBOR_RIGHT_SIDE, Vector2i.RIGHT], [TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, Vector2i.DOWN], [TileSet.CELL_NEIGHBOR_LEFT_SIDE, Vector2i.LEFT], [TileSet.CELL_NEIGHBOR_TOP_SIDE, Vector2i.UP]]:
				var neighbor: TileData = layer.get_cell_tile_data(cell + pair[1])
				var expected: int = 0 if neighbor != null and neighbor.terrain == 0 else -1
				checks += 1
				if tile.get_terrain_peering_bit(pair[0]) != expected:
					bad += 1
		report[layer_name] = {"cells":layer.get_used_cells().size(), "checks":checks, "mismatches":bad}
	print(JSON.stringify(report))
	field.free()
	quit()
