extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var fixture: Script = load("res://tests/support/farming_fixture.gd")
	var field: Node2D = fixture.create_field()
	root.add_child(field)
	await physics_frame
	var farm: Node = field.get_node("FarmingController")
	var paths: TileMapLayer = field.get_node("FieldBoundaries") as TileMapLayer
	var cells: Array[Vector2i] = paths.get_used_cells()
	assert(cells.size() == 299)
	for cell: Vector2i in cells:
		fixture.mark_cell(field, cell)
		assert(paths.get_cell_tile_data(cell).get_custom_data("blocks_farming") == true)
		assert(not farm.can_till(cell))
		assert(not farm._allowed(cell, &"can_plant", null))
		assert(not farm._allowed(cell, &"can_water", null))
	var ordinary: Vector2i = Vector2i(20, 24)
	fixture.mark_cell(field, ordinary)
	assert(farm.can_till(ordinary))
	assert(farm.till(ordinary))
	assert(farm.can_plant(ordinary))
	print("PASS: all 299 path tiles block till/plant/water; ordinary plot still tills and plants")
	field.free()
	quit()
