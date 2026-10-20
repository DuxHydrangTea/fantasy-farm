class_name PlayerNavigationComponent
extends Node
## Approach a clicked focus point using the player's real collision footprint.

@export var movement: MovementComponent
@export var animation: AnimationComponent
@export var camera: Camera2D
@export var collision_shape: CollisionShape2D
@export var farming_actions: FarmingActionComponent
@export_range(4.0, 16.0, 1.0) var cell_size: float = 8.0
@export_range(8.0, 32.0, 1.0) var interaction_distance: float = 20.0

var has_focus: bool = false
var is_navigating: bool = false
var focus_position: Vector2 = Vector2.ZERO
var _grid: AStarGrid2D
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _needs_path: bool = false
var _replans: int = 0
var _blocked_cells: Dictionary[Vector2i, bool] = {}

func _ready() -> void:
	assert(movement != null and animation != null and camera != null and collision_shape != null,
		"Assign player navigation references")

func request_focus(point: Vector2) -> void:
	cancel()
	focus_position = point
	has_focus = true
	is_navigating = true
	_needs_path = true

func cancel() -> void:
	has_focus = false
	is_navigating = false
	_needs_path = false
	_path.clear()
	_path_index = 0
	_replans = 0
	_blocked_cells.clear()
	movement.cancel_target()

func move(delta: float) -> void:
	if not has_focus:
		return
	if _needs_path:
		_needs_path = false
		if not _build_path():
			_finish()
	if not is_navigating:
		movement.stop()
		_face_focus()
		return
	while _path_index < _path.size() and movement.body.global_position.distance_to(_path[_path_index]) <= movement.arrival_distance:
		_path_index += 1
	if _path_index >= _path.size():
		_finish()
		return
	var waypoint: Vector2 = _path[_path_index]
	if not _segment_clear(movement.body.global_position, waypoint):
		if not _point_clear(waypoint):
			_blocked_cells[_cell(waypoint)] = true
		_replan()
		return
	if not movement.has_target or movement.target_position != waypoint:
		movement.set_target(waypoint)
	animation.update_facing_direction(movement.target_direction())
	movement.move_to_target(delta)
	if not movement.has_target and movement.body.global_position.distance_to(waypoint) > movement.arrival_distance:
		_replan()
	elif _path_index == _path.size() - 1 and movement.body.global_position.distance_to(waypoint) <= movement.arrival_distance:
		_finish()

func _finish() -> void:
	is_navigating = false
	_path.clear()
	movement.cancel_target()
	movement.stop()
	_face_focus()

func _face_focus() -> void:
	animation.update_facing_direction(_facing_point() - movement.body.global_position)

func _facing_point() -> Vector2:
	var farming: FarmingController = farming_actions.get_farming_controller() if farming_actions != null else null
	if farming == null:
		return focus_position
	# Clicking a tile corner still means facing that tile, not an adjacent one.
	return farming.farmland.to_global(farming.farmland.map_to_local(farming.world_to_cell(focus_position)))

func _replan() -> void:
	movement.cancel_target()
	movement.stop()
	_replans += 1
	if _replans > 3:
		_finish()
	else:
		_needs_path = true

func _query(point: Vector2) -> PhysicsShapeQueryParameters2D:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.transform.origin += point - movement.body.global_position
	query.collision_mask = movement.body.collision_mask
	query.exclude = [movement.body.get_rid()]
	query.margin = 0.25
	return query

func _point_clear(point: Vector2) -> bool:
	return movement.body.get_world_2d().direct_space_state.intersect_shape(_query(point), 1).is_empty()

func _segment_clear(from: Vector2, to: Vector2) -> bool:
	if not _point_clear(to):
		return false
	var query: PhysicsShapeQueryParameters2D = _query(from)
	query.motion = to - from
	var fractions: PackedFloat32Array = movement.body.get_world_2d().direct_space_state.cast_motion(query)
	return fractions[0] >= 0.9999

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi((point.x - camera.limit_left) / cell_size) - 1,
		roundi((point.y - camera.limit_top) / cell_size) - 1)

func _point(cell: Vector2i) -> Vector2:
	return Vector2(camera.limit_left, camera.limit_top) + (Vector2(cell) + Vector2.ONE) * cell_size

func _in_focus_range(point: Vector2) -> bool:
	if point.distance_to(focus_position) > interaction_distance:
		return false
	var farming: FarmingController = farming_actions.get_farming_controller() if farming_actions != null else null
	if farming == null:
		return true
	# The farming tool acts on the adjacent cell in the facing direction.
	var offset: Vector2i = farming.world_to_cell(focus_position) - farming.world_to_cell(point)
	var direction: Vector2 = _facing_point() - point
	var facing: Vector2i = Vector2i(signi(offset.x), 0) if absf(direction.x) > absf(direction.y) else Vector2i(0, signi(offset.y))
	return absi(offset.x) + absi(offset.y) == 1 and offset == facing

func _goal_valid(point: Vector2) -> bool:
	# Arrival has a tolerance: it must not leave the actor across a tile boundary.
	var margin: float = movement.arrival_distance + 0.25
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if not _in_focus_range(point + direction * margin):
			return false
	return _in_focus_range(point)

func _build_path() -> bool:
	_path.clear()
	_path_index = 0
	var origin: Vector2 = movement.body.global_position
	if _in_focus_range(origin):
		is_navigating = false
		return true
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(
		floori(float(camera.limit_right - camera.limit_left) / cell_size) - 1,
		floori(float(camera.limit_bottom - camera.limit_top) / cell_size) - 1))
	if not bounds.has_point(_cell(origin)) or not bounds.has_point(_cell(focus_position)):
		return false
	# Most clicks need only a small area. Expand before declaring a target unreachable.
	var corridor: Rect2i = Rect2i(_cell(origin), Vector2i.ONE).expand(_cell(focus_position))
	for padding: int in [16, 64]:
		var region: Rect2i = corridor.grow(padding).intersection(bounds)
		if _build_path_in_region(region):
			return true
		if region == bounds:
			return false
	return _build_path_in_region(bounds)

func _build_path_in_region(region: Rect2i) -> bool:
	_path.clear()
	var origin: Vector2 = movement.body.global_position
	_grid = AStarGrid2D.new()
	_grid.region = region
	_grid.cell_size = Vector2.ONE * cell_size
	# Include the centers of 16px farm tiles/gates, not only their quarter points.
	_grid.offset = Vector2(camera.limit_left, camera.limit_top) + Vector2.ONE * cell_size
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell: Vector2i = Vector2i(x, y)
			_grid.set_point_solid(cell, _blocked_cells.has(cell) or not _point_clear(_point(cell)))
	var start: Vector2i = Vector2i(-1, -1)
	var start_distance: float = INF
	var origin_cell: Vector2i = _cell(origin)
	for y: int in range(origin_cell.y - 2, origin_cell.y + 3):
		for x: int in range(origin_cell.x - 2, origin_cell.x + 3):
			var cell: Vector2i = Vector2i(x, y)
			if not _grid.region.has_point(cell) or _grid.is_point_solid(cell):
				continue
			var distance: float = origin.distance_squared_to(_point(cell))
			if distance < start_distance and _segment_clear(origin, _point(cell)):
				start = cell
				start_distance = distance
	if start == Vector2i(-1, -1):
		return false
	var focus_cell: Vector2i = _cell(focus_position)
	var reach: int = ceili(interaction_distance / cell_size)
	var best_length: float = INF
	for y: int in range(focus_cell.y - reach, focus_cell.y + reach + 1):
		for x: int in range(focus_cell.x - reach, focus_cell.x + reach + 1):
			var goal: Vector2i = Vector2i(x, y)
			if goal == focus_cell or not _grid.region.has_point(goal) or _grid.is_point_solid(goal):
				continue
			if not _goal_valid(_point(goal)):
				continue
			var ids: Array[Vector2i] = _grid.get_id_path(start, goal)
			if ids.is_empty():
				continue
			var length: float = sqrt(start_distance) + float(ids.size() - 1) * cell_size
			if length >= best_length:
				continue
			best_length = length
			_path.clear()
			for cell: Vector2i in ids:
				_path.append(_point(cell))
	if _path.is_empty():
		return false
	_smooth_path(origin)
	return true

func _smooth_path(origin: Vector2) -> void:
	# Keep only collision-clear turns; stopping at every grid cell feels jerky.
	var smoothed: PackedVector2Array = PackedVector2Array()
	var next_index: int = 0
	while next_index < _path.size():
		var chosen: int = next_index
		for index: int in range(_path.size() - 1, next_index - 1, -1):
			if _segment_clear(origin, _path[index]):
				chosen = index
				break
		origin = _path[chosen]
		smoothed.append(origin)
		next_index = chosen + 1
	_path = smoothed
