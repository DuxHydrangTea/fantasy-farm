extends SceneTree
## Read-only G4 mapping: exact raw pixel matches, no guessed grass tiles.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var quad: QuadMesh = QuadMesh.new()
	var arrays: Array = quad.surface_get_arrays(0)
	print("QUAD_LAYOUT=" + str(arrays[Mesh.ARRAY_TEX_UV]) + " INDEX=" + str(arrays[Mesh.ARRAY_INDEX]))
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/Outdoor decoration/Outdoor_Decor.png"))
	image.convert(Image.FORMAT_RGBA8)
	var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path(GrassSourceCatalog.ATLAS_PATH))
	var matches: Array[Dictionary] = []
	for y: int in range(10):
		for x: int in range(9):
			var tile: Image = image.get_region(Rect2i(x * 16, y * 16, 16, 16))
			for type: int in range(18):
				for frame: int in range(8):
					if _same_visible(tile, atlas.get_region(Rect2i(frame * 16, type * 16, 16, 16))):
						matches.append({"coords": [x, y], "type": type, "frame": frame})
	var scene: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	var layer: TileMapLayer = scene.get_node("TinyDecor") as TileMapLayer
	var points: Array[Dictionary] = []
	for cell: Vector2i in layer.get_used_cells_by_id(4):
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		for match_row: Dictionary in matches:
			if coords == Vector2i(match_row.coords[0], match_row.coords[1]):
				var point: Vector2 = layer.position + layer.map_to_local(cell)
				points.append({"cell": [cell.x, cell.y], "point": [point.x, point.y], "coords": match_row.coords, "type": match_row.type, "frame": match_row.frame})
	var static_grass: Array[Dictionary] = []
	for cell: Vector2i in layer.get_used_cells_by_id(4):
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		if coords in [Vector2i(6, 2), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)]:
			var point: Vector2 = layer.position + layer.map_to_local(cell)
			static_grass.append({"cell": [cell.x, cell.y], "point": [point.x, point.y], "coords": [coords.x, coords.y]})
	var pens: Array[Dictionary] = []
	var overlaps: Array[Dictionary] = []
	for candidate: Dictionary in static_grass:
		var point: Vector2 = Vector2(candidate.point[0], candidate.point[1])
		if not Rect2(1008, 592, 384, 272).has_point(point):
			continue
		var cell: Vector2i = Vector2i(candidate.cell[0], candidate.cell[1])
		var sort_y: float = point.y + layer.get_cell_tile_data(cell).y_sort_origin
		for other: Vector2i in layer.get_used_cells():
			if other == cell:
				continue
			var source: TileSetSource = layer.tile_set.get_source(layer.get_cell_source_id(other))
			var coords: Vector2i = layer.get_cell_atlas_coords(other)
			if not source is TileSetAtlasSource or not source.has_tile(coords):
				continue
			var data: TileData = layer.get_cell_tile_data(other)
			var center: Vector2 = layer.map_to_local(other)
			var size: Vector2 = Vector2(source.get_tile_texture_region(coords).size)
			if center.y + data.y_sort_origin == sort_y and Rect2(point - Vector2(8, 8), Vector2(16, 16)).grow(12).intersects(Rect2(center - size * 0.5, size)):
				overlaps.append({"candidate": candidate.cell, "other": [other.x, other.y], "source": layer.get_cell_source_id(other), "coords": [coords.x, coords.y], "sort_y": sort_y})
	for child: Node in scene.get_children():
		if child is AnimalPen:
			pens.append({"name": child.name, "position": [child.position.x, child.position.y], "bounds": str(child.bounds)})
	var result: Dictionary = {"matches": matches, "points": points, "static_grass": static_grass, "overlaps": overlaps, "pens": pens, "layer_position": str(layer.position)}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else "user://farm-grass-audit.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("FARM_GRASS_AUDIT=" + JSON.stringify({"matches": matches, "points": points.size(), "pens": pens}))
	scene.free()
	quit()

func _same_visible(a: Image, b: Image) -> bool:
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	for i: int in range(0, left.size(), 4):
		if left[i + 3] != right[i + 3]:
			return false
		if left[i + 3] > 0 and (left[i] != right[i] or left[i + 1] != right[i + 1] or left[i + 2] != right[i + 2]):
			return false
	return true
