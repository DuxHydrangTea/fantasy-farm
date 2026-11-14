class_name WorkerNavigationSystem
extends Node
## Sparse footprint-specific walkability shared by the team. Searches expand in
## round-robin order with a common time/query/expansion budget, including A*.
const QUERY_BUDGET: int = 96
const EXPANSION_BUDGET: int = 384
const TIME_BUDGET_USEC: int = 1500
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var world: FarmWorld
var caches: Dictionary = {}
var jobs: Array[Dictionary] = []
var cursor: int = 0
var queries_last_step: int = 0
var expansions_last_step: int = 0
var total_queries: int = 0
var completed_paths: int = 0
var failed_paths: int = 0
var geometry_revision: int = 0
var _pumped_frame: int = -1
var _static_areas: Dictionary = {}
var profiling: bool = false
var profile_usec: int = 0
var profile_max_usec: int = 0

func _ready() -> void:
	get_tree().node_added.connect(_geometry_changed)
	get_tree().node_removed.connect(_geometry_removed)
	_connect_tiles.call_deferred()

func _connect_tiles() -> void:
	for child: Node in world.get_children():
		if child is TileMapLayer and child.tile_set != null and child.tile_set.get_physics_layers_count() > 0:
			child.changed.connect(reset_cache)
	for body: Node in world.find_children("*", "StaticBody2D", true, false):
		_geometry_changed(body)

func reset() -> void:
	jobs.clear()
	caches.clear()
	cursor = 0
	geometry_revision += 1

func _geometry_removed(node: Node) -> void:
	var id: int = node.get_instance_id()
	if _static_areas.has(id):
		invalidate_region(_static_areas[id])
		_static_areas.erase(id)

func reset_cache() -> void:
	geometry_revision += 1
	caches.clear()
	_restart_jobs()

func _geometry_changed(node: Node) -> void:
	if not node is StaticBody2D or not world.is_ancestor_of(node):
		return
	var body: StaticBody2D = node as StaticBody2D
	var area: Rect2 = Rect2(body.global_position, Vector2.ZERO)
	var found_shape: bool = false
	for child: Node in body.find_children("*", "CollisionShape2D", true, false):
		var shape: CollisionShape2D = child as CollisionShape2D
		if shape.shape == null:
			continue
		var rect: Rect2 = shape.shape.get_rect()
		found_shape = true
		for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			area = area.expand(shape.to_global(point))
	for child: Node in body.find_children("*", "CollisionPolygon2D", true, false):
		var polygon: CollisionPolygon2D = child as CollisionPolygon2D
		for point: Vector2 in polygon.polygon:
			found_shape = true
			area = area.expand(polygon.to_global(point))
	if not found_shape:
		_static_areas[body.get_instance_id()] = Rect2(body.global_position - Vector2.ONE * 24.0, Vector2.ONE * 48.0)
		reset_cache()
		return
	# Include footprint width and grid rounding. Deferred restarts see new physics.
	area = area.grow(24.0)
	_static_areas[body.get_instance_id()] = area
	invalidate_region(area)

func invalidate_region(area: Rect2) -> void:
	geometry_revision += 1
	for cache: Dictionary in caches.values():
		var cells: Dictionary = cache.cells
		var size: float = float(cache.size)
		var origin: Vector2 = cache.origin
		var first: Vector2i = Vector2i(((area.position - origin) / size).floor())
		var last: Vector2i = Vector2i(((area.end - origin) / size).ceil())
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				cells.erase(Vector2i(x, y))
				var cell: Vector2i = Vector2i(x, y)
				cache.edges.erase(cell)
				for direction: Vector2i in DIRECTIONS:
					cache.edges.erase(cell + direction)
	_restart_jobs(area)

func _restart_jobs(area: Rect2 = Rect2()) -> void:
	# Plans are transient; task records and work progress remain untouched.
	var pending: Array[Dictionary] = jobs.duplicate()
	jobs.clear()
	for job: Dictionary in pending:
		var nav: WorkerNavigation = job.nav.get_ref() as WorkerNavigation
		if is_instance_valid(nav) and nav.has_focus:
			var affected: bool = area.size.is_zero_approx()
			if not affected:
				var first: Vector2i = nav._cell(area.position) - Vector2i.ONE
				var last: Vector2i = nav._cell(area.end) + Vector2i.ONE
				for y: int in range(first.y, last.y + 1):
					for x: int in range(first.x, last.x + 1):
						if job.cost.has(Vector2i(x, y)) or job.start == Vector2i(x, y):
							affected = true
							break
					if affected:
						break
			if affected:
				request(nav)
			else:
				jobs.append(job)

func cancel(nav: WorkerNavigation) -> void:
	for index: int in range(jobs.size() - 1, -1, -1):
		if jobs[index].nav.get_ref() == nav:
			jobs.remove_at(index)

func request(nav: WorkerNavigation) -> void:
	cancel(nav)
	var shape: CollisionShape2D = nav.collision_shape
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(floori(float(nav.camera.limit_right - nav.camera.limit_left) / nav.cell_size) - 1, floori(float(nav.camera.limit_bottom - nav.camera.limit_top) / nav.cell_size) - 1))
	var origin: Vector2 = Vector2(nav.camera.limit_left, nav.camera.limit_top) + Vector2.ONE * nav.cell_size
	var key: String = str([nav.movement.body.get_world_2d().space, shape.shape.get_rid(), shape.shape.get_rect(), shape.transform, nav.movement.body.global_scale, nav.movement.body.global_rotation, nav.movement.body.collision_mask, bounds, origin, nav.cell_size])
	if not caches.has(key):
		caches[key] = {"cells": {}, "edges": {}, "origin": origin, "size": nav.cell_size}
	var job: Dictionary = {"nav": weakref(nav), "key": key, "bounds": bounds, "open": [], "cost": {}, "parent": {}, "closed": {}, "phase": 0, "seed": 0, "start": Vector2i.ZERO, "start_distance": INF, "origin": nav.movement.body.global_position, "neighbour": 0, "current": Vector2i.ZERO}
	jobs.append(job)
	nav._planning = true

func _physics_process(_delta: float) -> void:
	pump()

func pump() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _pumped_frame:
		return
	_pumped_frame = frame
	queries_last_step = 0
	expansions_last_step = 0
	var started: int = Time.get_ticks_usec()
	while not jobs.is_empty() and queries_last_step < QUERY_BUDGET - 3 and expansions_last_step < EXPANSION_BUDGET and Time.get_ticks_usec() - started < TIME_BUDGET_USEC:
		cursor %= jobs.size()
		var job: Dictionary = jobs[cursor]
		var nav: WorkerNavigation = job.nav.get_ref() as WorkerNavigation
		if not is_instance_valid(nav) or not nav.has_focus:
			jobs.remove_at(cursor)
			continue
		var before_queries: int = nav.total_physics_queries
		var finished: bool = _expand(job, nav)
		total_queries += nav.total_physics_queries - before_queries
		if finished:
			jobs.remove_at(cursor)
		else:
			cursor += 1
		expansions_last_step += 1
	if profiling:
		var spent: int = Time.get_ticks_usec() - started
		profile_usec += spent
		profile_max_usec = maxi(profile_max_usec, spent)

func _clear(job: Dictionary, nav: WorkerNavigation, cell: Vector2i) -> bool:
	if not (job.bounds as Rect2i).has_point(cell):
		return false
	var cells: Dictionary = caches[job.key].cells
	if not cells.has(cell):
		queries_last_step += 1
		cells[cell] = nav._point_clear(nav._point(cell))
	return bool(cells[cell])

func _edge_clear(job: Dictionary, nav: WorkerNavigation, from: Vector2i, to: Vector2i) -> bool:
	# Clear endpoints can straddle a thin fence. Cache swept connections as well
	# as cells, shared by workers with the same collision footprint.
	var edges: Dictionary = caches[job.key].edges
	if not edges.has(from):
		edges[from] = {}
	var neighbours: Dictionary = edges[from]
	if not neighbours.has(to):
		queries_last_step += 2
		neighbours[to] = nav._segment_clear(nav._point(from), nav._point(to))
	return bool(neighbours[to])

func _expand(job: Dictionary, nav: WorkerNavigation) -> bool:
	if int(job.phase) == 0:
		if not (job.bounds as Rect2i).has_point(nav._cell(job.origin)) or not (job.bounds as Rect2i).has_point(nav._cell(nav.focus_position)):
			return _failed(nav)
		# One direct-path test per request. Swept footprint prevents fence cuts.
		queries_last_step += 2
		if nav._segment_clear(job.origin, nav.focus_position):
			nav.accept_path(PackedVector2Array([nav.focus_position]))
			completed_paths += 1
			return true
		if nav.exact_goal:
			queries_last_step += 1
			if not nav._point_clear(nav.focus_position):
				return _failed(nav)
		job.phase = 1
		return false
	if int(job.phase) == 1:
		# Find the closest safely connected grid point, incrementally (25 probes).
		var index: int = int(job.seed)
		if index < 25:
			var cell: Vector2i = nav._cell(job.origin) + Vector2i(index % 5 - 2, index / 5 - 2)
			job.seed = index + 1
			var distance: float = (job.origin as Vector2).distance_squared_to(nav._point(cell))
			if distance < float(job.start_distance) and _clear(job, nav, cell):
				queries_last_step += 2
				if nav._segment_clear(job.origin, nav._point(cell)):
					job.start = cell
					job.start_distance = distance
			return false
		if not is_finite(float(job.start_distance)):
			return _failed(nav)
		job.phase = 2
		job.cost[job.start] = 0
		_push(job.open, [_heuristic(nav, job.start), 0, job.start])
		return false
	if int(job.phase) == 2:
		if job.open.is_empty():
			return _failed(nav)
		var entry: Array = _pop(job.open)
		var cell: Vector2i = entry[2]
		if job.closed.has(cell):
			return false
		job.closed[cell] = true
		var point: Vector2 = nav._point(cell)
		var near_goal: bool = point.distance_squared_to(nav.focus_position) <= nav.interaction_distance * nav.interaction_distance
		var reaches_goal: bool = false
		if near_goal and nav.exact_goal:
			queries_last_step += 2
			reaches_goal = nav._segment_clear(point, nav.focus_position)
		elif near_goal:
			reaches_goal = nav._goal_valid(point)
		if reaches_goal:
			var path: PackedVector2Array = PackedVector2Array()
			if nav.exact_goal and not point.is_equal_approx(nav.focus_position):
				path.append(nav.focus_position)
			while job.parent.has(cell):
				path.append(nav._point(cell))
				cell = job.parent[cell]
			path.append(nav._point(cell))
			path.reverse()
			nav.accept_path(path)
			completed_paths += 1
			return true
		job.current = cell
		job.neighbour = 0
		job.phase = 3
		return false
	var current: Vector2i = job.current
	var next: Vector2i = current + DIRECTIONS[int(job.neighbour)]
	job.neighbour = int(job.neighbour) + 1
	if int(job.neighbour) == 4:
		job.phase = 2
	var cost: int = int(job.cost[current]) + 1
	if not job.closed.has(next) and cost < int(job.cost.get(next, 0x7FFFFFFF)) and _clear(job, nav, next) and _edge_clear(job, nav, current, next):
		job.cost[next] = cost
		job.parent[next] = current
		_push(job.open, [float(cost) + _heuristic(nav, next), cost, next])
	return false

func _failed(nav: WorkerNavigation) -> bool:
	failed_paths += 1
	nav.accept_path(PackedVector2Array())
	return true

func _heuristic(nav: WorkerNavigation, cell: Vector2i) -> float:
	var offset: Vector2i = nav._cell(nav.focus_position) - cell
	return maxf(0.0, float(absi(offset.x) + absi(offset.y)) - nav.interaction_distance / nav.cell_size * 1.414214)

func _push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if float(heap[parent][0]) <= float(entry[0]):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry

func _pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return first
	var index: int = 0
	while index * 2 + 1 < heap.size():
		var child: int = index * 2 + 1
		if child + 1 < heap.size() and float(heap[child + 1][0]) < float(heap[child][0]):
			child += 1
		if float(last[0]) <= float(heap[child][0]):
			break
		heap[index] = heap[child]
		index = child
	heap[index] = last
	return first
