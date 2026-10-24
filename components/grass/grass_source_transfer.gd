class_name GrassSourceTransfer
extends RefCounted
## Transaction over exact, validated cells. Never hide a mixed TileMapLayer.
const DATA = preload("res://resources/grass/farm_grass_data.gd")
const SOURCE: String = "res://assets/Outdoor decoration/Outdoor_Decor.png"
var records: Array[Dictionary] = []
var suppressed: bool = false
var restore_conflicts: int = 0
var retained_overlaps: int = 0

func prepare(layer: TileMapLayer, root: Node2D, region: Rect2) -> Array[Dictionary]:
	restore()
	records.clear()
	retained_overlaps = 0
	var samples: Array[Dictionary] = []
	if layer == null or layer.tile_set == null or not layer.enabled or not layer.visible or not layer.y_sort_enabled or layer.material != null or layer.modulate != Color.WHITE or layer.self_modulate != Color.WHITE:
		return samples
	var space: Transform2D = root.global_transform.affine_inverse() * layer.global_transform
	for cell: Vector2i in layer.get_used_cells():
		var source_id: int = layer.get_cell_source_id(cell)
		var source: TileSetSource = layer.tile_set.get_source(source_id)
		if not source is TileSetAtlasSource or source.texture == null or source.texture.resource_path != SOURCE:
			continue
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		if not source.has_tile(coords) or layer.get_cell_alternative_tile(cell) != 0:
			continue
		var type: int = -1
		for row: Dictionary in DATA.TYPES:
			if coords == Vector2i(row.coords[0], row.coords[1]):
				type = int(row.row)
				break
		if type < 0 or source.get_tile_texture_region(coords) != Rect2i(coords * 16, Vector2i(16, 16)) or source.get_tile_animation_frames_count(coords) != 1:
			continue
		var tile: TileData = layer.get_cell_tile_data(cell)
		if not _plain_visual(tile, layer.tile_set):
			continue
		var center: Vector2 = layer.map_to_local(cell)
		if not region.has_point(space * center):
			continue
		var physical: Vector2 = center + Vector2(0, float(DATA.TYPES[type].root_y) - 8.0)
		var sorting: Vector2 = Vector2(0, center.y + tile.y_sort_origin + layer.y_sort_origin)
		samples.append({"type": type, "transform": space * Transform2D(0.0, physical),
			"sort_origin": space * sorting, "phase": 0.0, "tall": true, "z_index": layer.z_index + tile.z_index})
		records.append({"layer": weakref(layer), "cell": cell, "source": source_id, "coords": coords, "alternative": 0})
	# A mixed TileMap row can draw grass between other translucent decorations.
	# A sibling GPU batch cannot insert inside that command list. Keep any such
	# overlapping component authored, instead of changing flowers or alpha order.
	var rows: Dictionary = _row_rectangles(layer, space)
	var inverse: Transform2D = root.global_transform.affine_inverse()
	var margin: float = 12.0 * maxf(absf(inverse.x.x) + absf(inverse.y.x), absf(inverse.x.y) + absf(inverse.y.y))
	var changed: bool = true
	while changed:
		changed = false
		var selected: Dictionary = {}
		for record: Dictionary in records:
			selected[record.cell] = true
		for i: int in range(records.size() - 1, -1, -1):
			var sample: Dictionary = samples[i]
			var key: Vector2 = Vector2(sample.sort_origin.y, float(sample.z_index))
			var center: Vector2 = layer.map_to_local(records[i].cell)
			var area: Rect2 = (space * Rect2(center - Vector2(8, 8), Vector2(16, 16))).grow(margin)
			for other: Dictionary in rows.get(key, []):
				if not selected.has(other.cell) and area.intersects(other.rect):
					records.remove_at(i)
					samples.remove_at(i)
					retained_overlaps += 1
					changed = true
					break
	# Preserve the TileMap's X order inside a same-Y GPU batch.
	var order: Array[int] = []
	for i: int in range(records.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return records[a].cell.x > records[b].cell.x if layer.x_draw_order_reversed else records[a].cell.x < records[b].cell.x)
	var ordered_records: Array[Dictionary] = []
	var ordered_samples: Array[Dictionary] = []
	for i: int in order:
		ordered_records.append(records[i])
		ordered_samples.append(samples[i])
	records = ordered_records
	return ordered_samples

func _row_rectangles(layer: TileMapLayer, space: Transform2D) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		var source: TileSetSource = layer.tile_set.get_source(layer.get_cell_source_id(cell))
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		if not source is TileSetAtlasSource or not source.has_tile(coords):
			continue
		var tile: TileData = layer.get_cell_tile_data(cell)
		if tile == null:
			continue
		var center: Vector2 = layer.map_to_local(cell)
		var point: Vector2 = space * Vector2(0, center.y + tile.y_sort_origin + layer.y_sort_origin)
		var key: Vector2 = Vector2(point.y, float(layer.z_index + tile.z_index))
		var size: Vector2 = Vector2(source.get_tile_texture_region(coords).size)
		# Conservative around unusual origin/flip/transpose on protected props.
		var side: float = maxf(size.x, size.y)
		var rect: Rect2 = Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		rect = rect.grow(maxf(absf(tile.texture_origin.x), absf(tile.texture_origin.y)))
		if not result.has(key):
			result[key] = []
		result[key].append({"cell": cell, "rect": space * rect})
	return result

func _plain_visual(tile: TileData, tiles: TileSet) -> bool:
	if tile == null or tile.material != null or tile.modulate != Color.WHITE or tile.texture_origin != Vector2i.ZERO or tile.flip_h or tile.flip_v or tile.transpose:
		return false
	for i: int in range(tiles.get_physics_layers_count()):
		if tile.get_collision_polygons_count(i) != 0:
			return false
	for i: int in range(tiles.get_navigation_layers_count()):
		if tile.get_navigation_polygon(i) != null:
			return false
	return true

func suppress() -> bool:
	if suppressed:
		return true
	# Validate the ENTIRE transaction before modifying any cell.
	for record: Dictionary in records:
		var layer: TileMapLayer = record.layer.get_ref() as TileMapLayer
		if layer == null or layer.get_cell_source_id(record.cell) != record.source or layer.get_cell_atlas_coords(record.cell) != record.coords or layer.get_cell_alternative_tile(record.cell) != record.alternative:
			return false
	for record: Dictionary in records:
		var layer: TileMapLayer = record.layer.get_ref() as TileMapLayer
		layer.erase_cell(record.cell)
	suppressed = true
	return true

func restore() -> void:
	if not suppressed:
		return
	for record: Dictionary in records:
		var layer: TileMapLayer = record.layer.get_ref() as TileMapLayer
		if layer == null:
			continue
		if layer.get_cell_source_id(record.cell) == -1:
			layer.set_cell(record.cell, record.source, record.coords, record.alternative)
		elif layer.get_cell_source_id(record.cell) != record.source or layer.get_cell_atlas_coords(record.cell) != record.coords or layer.get_cell_alternative_tile(record.cell) != record.alternative:
			restore_conflicts += 1 # Preserve an external edit instead of overwriting it.
	suppressed = false
