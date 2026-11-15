class_name WorkerNavigation
extends PlayerNavigationComponent
## Điều hướng riêng cho công nhân thông qua WorkerNavigationSystem.
## Hỗ trợ đích chính xác hoặc phạm vi tương tác, kiểm tra waypoint và lập lại
## đường khi đoạn đường bị chặn.

## Bộ lập kế hoạch đường dùng chung của công nhân.
var system: WorkerNavigationSystem
## Yêu cầu đến sát đích theo arrival_distance thay vì phạm vi tương tác.
var exact_goal: bool = false
var _check_remaining: float = 0.0
var _checked_waypoint: Vector2 = Vector2.INF

func _ready() -> void:
	set_physics_process(false)

## Yêu cầu đi đến phạm vi tương tác quanh điểm.
func request_focus(point: Vector2) -> void:
	request_worker_goal(point, false)

## Hủy đường cũ và yêu cầu hệ thống lập đường đến đích với chế độ đã chọn.
## Yêu cầu trùng với đích và chế độ hiện tại được bỏ qua.
func request_worker_goal(point: Vector2, exact: bool) -> void:
	if has_focus and focus_position.is_equal_approx(point) and exact_goal == exact:
		return
	cancel()
	exact_goal = exact
	focus_position = point
	has_focus = true
	is_navigating = true
	system.request(self)

func _in_focus_range(point: Vector2) -> bool:
	if exact_goal:
		return point.distance_to(focus_position) <= movement.arrival_distance
	return super._in_focus_range(point)

## Hủy yêu cầu trong hệ thống và xóa trạng thái điều hướng hiện tại.
func cancel() -> void:
	if system != null:
		system.cancel(self)
	super.cancel()
	_checked_waypoint = Vector2.INF

func _exit_tree() -> void:
	if is_instance_valid(system):
		system.cancel(self)

## Nhận đường đã lập và gộp các đoạn cùng hướng, giữ các điểm đổi hướng.
## Đường rỗng kết thúc điều hướng.
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

## Đi theo waypoint, định kỳ kiểm tra đoạn đường và yêu cầu lập lại nếu bị chặn.
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
