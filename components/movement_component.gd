class_name MovementComponent
extends Node

@export var speed: float = 150.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600
@export var arrival_distance: float = 2.0
var body: CharacterBody2D
var has_target: bool = false
var target_position: Vector2 = Vector2.ZERO
var _blocked_time: float = 0.0

func _ready() -> void:
	body = get_parent() as CharacterBody2D
	assert(body != null, "MovementComponent phai la con truc tiep cua CharacterBody2D")

func move(dir: Vector2, delta: float, speed_limit: float = -1.0) -> void:
	var allowed_speed: float = speed if speed_limit < 0.0 else minf(speed, speed_limit)
	var target_velocity: Vector2 = dir.limit_length(1.0) * allowed_speed
	var rate := acceleration if not dir.is_zero_approx() else friction
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
	if speed_limit >= 0.0:
		body.velocity = body.velocity.limit_length(allowed_speed)
	body.move_and_slide()

func set_target(world_position: Vector2) -> void:
	target_position = world_position
	has_target = true
	_blocked_time = 0.0

func cancel_target() -> void:
	has_target = false
	_blocked_time = 0.0

func target_direction() -> Vector2:
	if not has_target or body.global_position.distance_to(target_position) <= arrival_distance:
		return Vector2.ZERO
	return body.global_position.direction_to(target_position)

# Giới hạn tốc độ bước cuối bằng khoảng cách còn lại / delta (pixel / giây).
# Ví dụ còn 2 pixel và tick 0,02 giây thì không đi nhanh hơn 100 pixel/giây trong bước đó.
# Nếu vẫn dùng toàn bộ tốc độ, quán tính có thể đưa nhân vật qua đích rồi quay lại, rung liên tục.
# max(delta, 0.0001) tránh chia cho 0; thời gian bị chặn giúp hủy đích khi mắc tường,
# để hệ thống tìm đường được lập kế hoạch lại thay vì đẩy vào vật cản mãi.
func move_to_target(delta: float) -> void:
	var direction: Vector2 = target_direction()
	if direction.is_zero_approx():
		cancel_target()
		stop()
		return
	var before: Vector2 = body.global_position
	# Cap this step so momentum cannot carry the character past the destination.
	move(direction, delta, before.distance_to(target_position) / maxf(delta, 0.0001))
	if body.global_position.distance_to(before) < 0.001:
		_blocked_time += delta
	else:
		_blocked_time = 0.0
	if body.global_position.distance_to(target_position) <= arrival_distance or _blocked_time >= 0.2:
		cancel_target()
		stop()

func stop() -> void:
	body.velocity = Vector2.ZERO
