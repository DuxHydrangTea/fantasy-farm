@tool
extends SceneTree

func _init() -> void:
	var path: String = "res://resources/tilesets/fence.tres"
	var ts: TileSet = load(path)
	if ts.get_physics_layers_count() == 0:
		ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	
	var box: PackedVector2Array = PackedVector2Array([
		Vector2(-8, -8),
		Vector2(8, -8),
		Vector2(8, 8),
		Vector2(-8, 8)
	])
	
	for i in range(ts.get_source_count()):
		var source_id: int = ts.get_source_id(i)
		var source: TileSetAtlasSource = ts.get_source(source_id) as TileSetAtlasSource
		for t in range(source.get_tiles_count()):
			var coords: Vector2i = source.get_tile_id(t)
			var data: TileData = source.get_tile_data(coords, 0)
			if data.get_collision_polygons_count(0) == 0:
				data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, box)
	
	var err: Error = ResourceSaver.save(ts, path)
	if err != OK:
		printerr("Failed to save fence.tres: ", err)
	else:
		print("Successfully saved fence.tres with collision polygons!")
	quit()
