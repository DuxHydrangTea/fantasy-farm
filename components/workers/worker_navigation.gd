class_name WorkerNavigation
extends PlayerNavigationComponent
## Worker-only movement adapter. Player navigation and input remain independent.
var system: WorkerNavigationSystem
var _check_remaining: float = 0.0
var _checked_waypoint: Vector2 = Vector2.INF

func _ready() -> void:
	set_physics_process(false)

func request_focus(point: Vector2) -> void:
	if has_focus and focus_position.is_equal_approx(point):
		return
	cancel()
	focus_position = point
	has_focus = true
	is_navigating = true
	system.request(self)

func cancel() -> void:
	if system != null:
		system.cancel(self)
	super.cancel()
	_checked_waypoint = Vector2.INF

func _exit_tree() -> void:
	if is_instance_valid(system):
		system.cancel(self)

func accept_path(path: PackedVector2Array) -> void:
	_planning = false
	_path.clear()
	# Collapse only collinear runs: this never shortcuts through a wall.
	for index: int in range(path.size()):
		if index == 0 or index == path.size() - 1 or (path[index] - path[index - 1]) != (path[index + 1] - path[index]):
			_path.append(path[index])
	_path_index = 0
	_checked_waypoint = Vector2.INF
	if _path.is_empty():
		_finish()

func move(delta: float) -> void:
	if not has_focus or not is_navigating:
		return
	if _planning:
		movement.stop()
		return
	while _path_index < _path.size() and movement.body.global_position.distance_to(_path[_path_index]) <= movement.arrival_distance:
		_path_index += 1
	if _path_index >= _path.size():
		_finish()
		return
	var waypoint: Vector2 = _path[_path_index]
	_check_remaining -= delta
	if waypoint != _checked_waypoint or _check_remaining <= 0.0:
		_check_remaining = 0.15
		_checked_waypoint = waypoint
		if not _segment_clear(movement.body.global_position, waypoint):
			_retry(waypoint)
			return
	if not movement.has_target or movement.target_position != waypoint:
		movement.set_target(waypoint)
	animation.update_facing_direction(movement.target_direction())
	movement.move_to_target(delta)
	if not movement.has_target and movement.body.global_position.distance_to(waypoint) > movement.arrival_distance:
		_retry(waypoint)

func _retry(waypoint: Vector2) -> void:
	movement.cancel_target()
	movement.stop()
	_replans += 1
	if _replans > 3:
		_finish()
		return
	system.invalidate_region(Rect2(movement.body.global_position, Vector2.ZERO).expand(waypoint).grow(16.0))
	system.request(self)
