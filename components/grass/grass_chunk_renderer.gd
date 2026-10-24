class_name GrassChunkRenderer
extends RefCounted
## Bounded GPU cache. Leaves are sibling CanvasItem RIDs under the actor sort root.
var resident: Dictionary = {}
var active: Array[Vector2i] = []
var builds: int = 0
var releases: int = 0
var allocated_leaves: int = 0
var freed_leaves: int = 0
var instances: int = 0
var lookups: int = 0
var last_error: String = ""
var mesh_override: Mesh
var _clock: int = 0
var _shown: bool = true

func select(index: GrassChunkIndex, region: Rect2i, parent: RID, catalog: GrassSourceCatalog, material: ShaderMaterial, margin: float, max_chunks: int, max_instances: int, max_batches: int = 2048) -> bool:
	lookups += 1
	# Reject pathological zoom BEFORE enumerating a huge empty world rectangle.
	if int(region.size.x) * int(region.size.y) > 16384:
		return _fail("View requests more than 16384 chunk coordinates; adjust zoom/chunk size")
	var wanted: Array[Vector2i] = index.lookup(region)
	var required: int = 0
	var required_batches: int = 0
	for key: Vector2i in wanted:
		required += int(index.chunks[key].instances)
		required_batches += index.chunks[key].groups.size()
	if wanted.size() > max_chunks or required > max_instances or required_batches > max_batches:
		return _fail("Visible/reserve grass exceeds configured resident budget; no partial grass selection")
	last_error = ""
	_clock += 1
	active = wanted
	# Mark active first, so visible chunks can never be evicted by LRU.
	for key: Vector2i in resident:
		resident[key].active = key in wanted
		if resident[key].active:
			resident[key].used = _clock
	for key: Vector2i in wanted:
		if resident.has(key):
			continue
		var count: int = int(index.chunks[key].instances)
		var batch_count: int = index.chunks[key].groups.size()
		while resident.size() >= max_chunks or instances + count > max_instances or allocated_leaves - freed_leaves + batch_count > max_batches:
			_evict_oldest()
		var leaves: Array[GrassPocRenderer] = []
		for group: Dictionary in index.chunks[key].groups.values():
			var leaf: GrassPocRenderer = GrassPocRenderer.new()
			var data: Array[Dictionary] = []
			data.assign(group.samples)
			leaf.build(parent, catalog, data, material, mesh_override)
			RenderingServer.canvas_item_set_default_texture_filter(leaf.canvas, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
			RenderingServer.canvas_item_set_transform(leaf.canvas, Transform2D(0.0, group.anchor))
			RenderingServer.canvas_item_set_z_index(leaf.canvas, int(group.z))
			leaf.update_bounds(margin)
			leaves.append(leaf)
			allocated_leaves += 1
		resident[key] = {"leaves": leaves, "instances": count, "used": _clock, "active": true}
		instances += count
		builds += 1
	_update_visibility()
	return true

func _fail(message: String) -> bool:
	clear()
	last_error = message
	return false

func _evict_oldest() -> void:
	var oldest: Vector2i
	var stamp: int = 9223372036854775807
	for key: Vector2i in resident:
		if not resident[key].active and int(resident[key].used) < stamp:
			oldest = key
			stamp = int(resident[key].used)
	assert(stamp < 9223372036854775807, "Active chunks must fit the validated budget")
	_release(oldest)

func _release(key: Vector2i) -> void:
	for leaf: GrassPocRenderer in resident[key].leaves:
		leaf.clear()
		freed_leaves += 1
	instances -= int(resident[key].instances)
	resident.erase(key)
	releases += 1

func show_field(shown: bool) -> void:
	_shown = shown
	_update_visibility()

func _update_visibility() -> void:
	for chunk: Dictionary in resident.values():
		for leaf: GrassPocRenderer in chunk.leaves:
			RenderingServer.canvas_item_set_visible(leaf.canvas, _shown and bool(chunk.active))

func update_bounds(margin: float) -> void:
	for chunk: Dictionary in resident.values():
		for leaf: GrassPocRenderer in chunk.leaves:
			leaf.update_bounds(margin)

func clear() -> void:
	for key: Vector2i in resident.keys():
		_release(key)
	active.clear()

func stats() -> Dictionary:
	return {"resident_chunks": resident.size(), "active_chunks": active.size(), "resident_instances": instances,
		"live_leaves": allocated_leaves - freed_leaves, "builds": builds, "releases": releases,
		"allocated_leaves": allocated_leaves, "freed_leaves": freed_leaves, "index_queries": lookups, "error": last_error}
