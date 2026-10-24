class_name GrassChunkIndex
extends RefCounted
## CPU authoring index, built once per dataset/transform edit, never per frame.
var chunks: Dictionary = {}
var chunk_size: int = 256
var extent: float = 0.0
var total_instances: int = 0

func build(values: Array[Dictionary], catalog: GrassSourceCatalog, size_pixels: int, into_sort_space: Transform2D) -> void:
	chunks.clear()
	extent = 0.0
	total_instances = values.size()
	chunk_size = maxi(16, size_pixels)
	for value: Dictionary in values:
		var pose: Transform2D = into_sort_space * (value.transform as Transform2D)
		var cell: Vector2i = coordinate(pose.origin)
		if not chunks.has(cell):
			chunks[cell] = {"groups": {}, "instances": 0}
		var tall: bool = bool(value.get("tall", true))
		var z: int = clampi(int(value.get("z_index", 0 if tall else -1)), -4096, 4096)
		var sort_y: float = pose.origin.y
		if value.has("sort_origin"):
			sort_y = (into_sort_space * (value.sort_origin as Vector2)).y
		# Exact foot Y, never rounded: fractional rows must retain actor ordering.
		var group_key: Vector3 = Vector3(sort_y if tall else 0.0, float(z), float(tall))
		var groups: Dictionary = chunks[cell].groups
		var anchor: Vector2 = Vector2(float(cell.x * chunk_size), sort_y if tall else float(cell.y * chunk_size))
		if not groups.has(group_key):
			groups[group_key] = {"anchor": anchor, "z": z, "samples": []}
		var local: Transform2D = pose
		local.origin -= anchor
		groups[group_key].samples.append({"type": int(value.type), "transform": local, "phase": float(value.get("phase", 0.0))})
		chunks[cell].instances += 1
		var rect: Rect2 = catalog.local_bounds(int(value.type))
		for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var offset: Vector2 = pose.basis_xform(point)
			extent = maxf(extent, maxf(absf(offset.x), absf(offset.y)))

func coordinate(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / float(chunk_size)), floori(point.y / float(chunk_size)))

func cell_rect(area: Rect2, margin: float) -> Rect2i:
	var expanded: Rect2 = area.grow(extent + maxf(0.0, margin))
	var first: Vector2i = coordinate(expanded.position)
	return Rect2i(first, coordinate(expanded.end) - first + Vector2i.ONE)

func lookup(area: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var key: Vector2i = Vector2i(x, y)
			if chunks.has(key):
				result.append(key)
	return result
