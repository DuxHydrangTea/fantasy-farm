class_name AnimalWanderComponent
extends Node
## Điều khiển vật nuôi đi lang thang trong chuồng bằng Movement và Animation.
## Với thủy cầm, component traversal cung cấp đường đi qua môi trường ao.

## Component di chuyển của actor.
@export var movement: MovementComponent
## Component cập nhật hướng và hoạt ảnh.
@export var animation: AnimationComponent
## Hình va chạm dùng để kiểm tra điểm đích.
@export var collision: CollisionShape2D
## Chuồng giới hạn vùng đi lại.
@export var pen: AnimalPen
## Seed thử nghiệm; 0 tạo seed ngẫu nhiên khi bắt đầu.
@export var random_seed: int = 0
## Khoảng thời gian nghỉ giữa các lần chọn đích, tính bằng giây.
var idle_seconds: Vector2 = Vector2(0.6, 1.8)
## Khoảng chừa từ rìa chuồng.
var margin: float = 12.0
## Bộ điều hướng ao tùy chọn.
var traversal: WaterfowlComponent
var _wait_remaining: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

func _physics_process(delta: float) -> void:
	step(delta)

## Cập nhật một bước đi lang thang, được AnimalBehaviourComponent gọi khi
## component hành vi quản lý trạng thái. Giữ actor trong chuồng và chọn đích mới.
func step(delta: float) -> void:
	if not is_instance_valid(pen):
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		return
	_keep_inside()
	if not movement.has_target:
		_wait_remaining -= delta
		if _wait_remaining <= 0.0:
			choose_target()
	var before: Vector2 = movement.body.global_position
	if movement.has_target:
		move_to_destination(delta)
		_keep_inside()
	var displacement: Vector2 = movement.body.global_position - before
	animation.update_facing_direction(displacement)
	animation.play("idle" if displacement.is_zero_approx() else "walk")
	if not movement.has_target:
		movement.stop()
		if _wait_remaining <= 0.0:
			_wait_remaining = _rng.randf_range(idle_seconds.x, idle_seconds.y)

## Thử tối đa 16 điểm ngẫu nhiên trong chuồng và chọn điểm trống đi tới được.
func choose_target() -> bool:
	if not is_instance_valid(pen):
		return false
	for attempt: int in range(16):
		var point: Vector2 = pen.sample_world(_rng, margin)
		if movement.body.global_position.distance_to(point) > movement.arrival_distance and _target_is_clear(point):
			if set_destination(point):
				return true
	return false

## Đặt đích trực tiếp hoặc yêu cầu bộ điều hướng ao lập đường.
func set_destination(point: Vector2) -> bool:
	if traversal != null:
		return traversal.set_destination(point)
	movement.set_target(point)
	return true

## Đi một bước theo đường ao hoặc di chuyển trực tiếp đến đích.
func move_to_destination(delta: float) -> void:
	if traversal != null:
		traversal.travel(delta)
	else:
		movement.move_to_target(delta)

## Hủy đường đi và dừng di chuyển.
func cancel_destination() -> void:
	if traversal != null:
		traversal.cancel()
	else:
		movement.cancel_target()
		movement.stop()

## Kiểm tra đích cuối hiện tại có xấp xỉ điểm yêu cầu.
func destination_matches(point: Vector2) -> bool:
	return traversal.destination.is_equal_approx(point) if traversal != null else movement.target_position.is_equal_approx(point)

## Trả chiều dài đường còn lại hoặc khoảng cách trực tiếp đến đích.
func route_distance() -> float:
	return traversal.distance_remaining() if traversal != null else movement.body.global_position.distance_to(movement.target_position)

func _keep_inside() -> void:
	var body: CharacterBody2D = movement.body
	if not pen.contains_world(body.global_position, margin):
		body.global_position = pen.clamp_world(body.global_position, margin)
		movement.cancel_target()
		movement.stop()
	if movement.has_target and not pen.contains_world(movement.target_position, margin):
		movement.cancel_target()
		movement.stop()

func _target_is_clear(point: Vector2) -> bool:
	if collision == null or collision.shape == null:
		return false
	if traversal != null and not traversal.can_reach(point):
		return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.transform.origin += point - movement.body.global_position
	query.collision_mask = movement.body.collision_mask
	query.exclude = [movement.body.get_rid()]
	return movement.body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
