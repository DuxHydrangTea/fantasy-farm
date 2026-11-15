class_name MovementComponent
extends Node
## Di chuyển CharacterBody2D cha bằng gia tốc, ma sát và đích tùy chọn.
## Hỗ trợ tìm đường vòng ngắn quanh vật cản bằng kiểm tra va chạm của body.

## Bước thử dịch ngang khi tìm đường vòng.
const DETOUR_STEP: float = 8.0
## Số bước dịch ngang tối đa mỗi phía.
const DETOUR_STEPS: int = 16
## Khoảng kiểm tra trước theo hướng di chuyển.
const DETOUR_LOOKAHEAD: float = 10.0
## Khoảng trống phía trước cần có tại điểm vòng.
const DETOUR_FORWARD_CLEARANCE: float = 24.0
## Thời gian chờ trước khi thử lại tìm đường vòng, tính bằng giây.
const DETOUR_RETRY_DELAY: float = 0.2

## Tốc độ tối đa theo đơn vị thế giới mỗi giây.
@export var speed: float = 150.0
## Gia tốc khi có hướng di chuyển.
@export var acceleration: float = 1200.0
## Tốc độ giảm vận tốc khi không có hướng.
@export var friction: float = 1600
## Khoảng cách tới đích được xem là đã đến.
@export var arrival_distance: float = 2.0
## CharacterBody2D cha, được xác định khi node sẵn sàng.
var body: CharacterBody2D
## Cho biết có đích di chuyển đang hoạt động.
var has_target: bool = false
## Tọa độ toàn cục của đích.
var target_position: Vector2 = Vector2.ZERO
var _blocked_time: float = 0.0
var _detour_direction: Vector2 = Vector2.ZERO
var _detour_side: Vector2 = Vector2.ZERO
var _detour_waypoint: Vector2 = Vector2.INF
var _detour_rounding_corner: bool = false
var _detour_retry_remaining: float = 0.0

func _ready() -> void:
	body = get_parent() as CharacterBody2D
	assert(body != null, "MovementComponent phai la con truc tiep cua CharacterBody2D")

## Cập nhật vận tốc theo hướng, gia tốc hoặc ma sát rồi gọi move_and_slide.
## Giới hạn tốc độ âm dùng tốc độ cấu hình; giá trị không âm đặt thêm trần.
func move(dir: Vector2, delta: float, speed_limit: float = -1.0) -> void:
	var allowed_speed: float = speed if speed_limit < 0.0 else minf(speed, speed_limit)
	var target_velocity: Vector2 = dir.limit_length(1.0) * allowed_speed
	var rate := acceleration if not dir.is_zero_approx() else friction
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
	if speed_limit >= 0.0:
		body.velocity = body.velocity.limit_length(allowed_speed)
	body.move_and_slide()

## Di chuyển theo hướng và thử lệch sang bên khi đường phía trước bị chặn.
## Nếu có [param goal], giữ hướng vòng qua góc đến khi đường thẳng tới đích thông.
func move_with_avoidance(dir: Vector2, delta: float, speed_limit: float = -1.0, goal: Vector2 = Vector2.INF) -> void:
	if dir.is_zero_approx():
		clear_detour()
		move(dir, delta, speed_limit)
		return
	var origin: Vector2 = body.global_position
	var forward: Vector2 = dir.normalized()
	# A patrol holds its course around the corner until it can see its actual waypoint again.
	if goal != Vector2.INF and (_detour_waypoint != Vector2.INF or _detour_rounding_corner):
		if _can_sweep(origin, goal - origin):
			clear_detour()
		else:
			forward = _detour_direction
	if forward.dot(_detour_direction) < 0.95:
		if _detour_waypoint != Vector2.INF:
			body.velocity = forward * maxf(0.0, body.velocity.dot(forward))
		clear_detour()
		_detour_direction = forward
	if _detour_waypoint != Vector2.INF:
		var remaining: Vector2 = _detour_waypoint - origin
		if remaining.dot(_detour_side) <= arrival_distance * 0.5 or _can_sweep(origin, forward * DETOUR_FORWARD_CLEARANCE):
			_detour_waypoint = Vector2.INF
			_detour_rounding_corner = goal != Vector2.INF
		elif _can_sweep(origin, remaining):
			_move_along_detour(remaining, dir.length(), delta, speed_limit)
			return
		else:
			_detour_waypoint = Vector2.INF
			_detour_retry_remaining = 0.0
	_detour_retry_remaining = maxf(0.0, _detour_retry_remaining - delta)
	# Leave room to turn before the body is flush with the wall or catches a fence post.
	var step: Vector2 = forward * maxf(DETOUR_LOOKAHEAD, speed * minf(dir.length(), 1.0) * delta)
	if _detour_retry_remaining <= 0.0 and not _can_sweep(origin, step):
		_find_detour(origin, forward)
		if _detour_waypoint != Vector2.INF:
			_move_along_detour(_detour_waypoint - origin, dir.length(), delta, speed_limit)
			return
		_detour_retry_remaining = DETOUR_RETRY_DELAY
	move(forward * dir.length(), delta, speed_limit)

func _find_detour(origin: Vector2, forward: Vector2) -> void:
	var side: Vector2 = forward.orthogonal()
	if _detour_side.dot(side) < 0.0:
		side = -side
	# Try the nearest passable offset first, starting on the previous side at each distance.
	for index: int in range(1, DETOUR_STEPS + 1):
		for tangent: Vector2 in [side, -side]:
			var offset: Vector2 = tangent * (DETOUR_STEP * index)
			if _can_sweep(origin + offset, forward * DETOUR_FORWARD_CLEARANCE) and _can_sweep(origin, offset):
				_detour_side = tangent
				_detour_waypoint = origin + offset
				return

func _can_sweep(origin: Vector2, motion: Vector2) -> bool:
	var transform_at_origin: Transform2D = body.global_transform
	transform_at_origin.origin = origin
	return not body.test_move(transform_at_origin, motion, null, body.safe_margin, true)

func _move_along_detour(remaining: Vector2, strength: float, delta: float, speed_limit: float) -> void:
	var step_limit: float = remaining.length() / maxf(delta, 0.0001)
	if speed_limit >= 0.0:
		step_limit = minf(step_limit, speed_limit)
	move(remaining.normalized() * strength, delta, step_limit)

## Xóa trạng thái đường vòng và thời gian chờ thử lại.
func clear_detour() -> void:
	_detour_direction = Vector2.ZERO
	_detour_side = Vector2.ZERO
	_detour_waypoint = Vector2.INF
	_detour_rounding_corner = false
	_detour_retry_remaining = 0.0

## Đặt đích toàn cục và đặt lại thời gian bị chặn.
func set_target(world_position: Vector2) -> void:
	if not world_position.is_equal_approx(target_position):
		clear_detour()
	target_position = world_position
	has_target = true
	_blocked_time = 0.0

## Hủy đích hiện tại và đặt lại thời gian bị chặn.
func cancel_target() -> void:
	has_target = false
	_blocked_time = 0.0

## Hướng đơn vị đến đích, hoặc vector 0 khi không có đích hay đã tới.
func target_direction() -> Vector2:
	if not has_target or body.global_position.distance_to(target_position) <= arrival_distance:
		return Vector2.ZERO
	return body.global_position.direction_to(target_position)

# Giới hạn tốc độ bước cuối bằng khoảng cách còn lại / delta (pixel / giây).
# Ví dụ còn 2 pixel và tick 0,02 giây thì không đi nhanh hơn 100 pixel/giây trong bước đó.
# Nếu vẫn dùng toàn bộ tốc độ, quán tính có thể đưa nhân vật qua đích rồi quay lại, rung liên tục.
# max(delta, 0.0001) tránh chia cho 0; thời gian bị chặn giúp hủy đích khi mắc tường,
# để hệ thống tìm đường được lập kế hoạch lại thay vì đẩy vào vật cản mãi.
## Di chuyển một bước đến đích, tùy chọn tránh vật cản.
## Giới hạn tốc độ bước cuối để không vượt đích; hủy đích khi đến nơi hoặc
## bị chặn liên tục 0,2 giây để nơi gọi có thể lập kế hoạch lại.
func move_to_target(delta: float, avoid_obstacles: bool = false) -> void:
	var direction: Vector2 = target_direction()
	if direction.is_zero_approx():
		cancel_target()
		stop()
		return
	var before: Vector2 = body.global_position
	# Cap this step so momentum cannot carry the character past the destination.
	var step_limit: float = before.distance_to(target_position) / maxf(delta, 0.0001)
	if avoid_obstacles:
		move_with_avoidance(direction, delta, step_limit, target_position)
	else:
		move(direction, delta, step_limit)
	if body.global_position.distance_to(before) < 0.001:
		_blocked_time += delta
	else:
		_blocked_time = 0.0
	if body.global_position.distance_to(target_position) <= arrival_distance or _blocked_time >= 0.2:
		cancel_target()
		stop()

## Xóa đường vòng và đặt vận tốc body về 0.
func stop() -> void:
	clear_detour()
	body.velocity = Vector2.ZERO
