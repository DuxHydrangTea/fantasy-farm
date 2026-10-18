extends Node
## Top-down patrol using the shared Movement/Animation components.
const Pen = preload("res://components/animals/animal_pen.gd")
@export var movement: MovementComponent
@export var animation: AnimationComponent
@export var collision: CollisionShape2D
@export var pen: Pen
@export var random_seed: int = 0
var idle_seconds: Vector2 = Vector2(0.6, 1.8)
var margin: float = 12.0
var _wait_remaining: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

func _physics_process(delta: float) -> void:
	step(delta)

## Called by AnimalBehaviourComponent when it owns the animal's state.
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
		movement.move_to_target(delta)
		_keep_inside()
	var displacement: Vector2 = movement.body.global_position - before
	animation.update_facing_direction(displacement)
	animation.play("idle" if displacement.is_zero_approx() else "walk")
	if not movement.has_target:
		movement.stop()
		if _wait_remaining <= 0.0:
			_wait_remaining = _rng.randf_range(idle_seconds.x, idle_seconds.y)

func choose_target() -> bool:
	if not is_instance_valid(pen):
		return false
	for attempt: int in range(16):
		var point: Vector2 = pen.sample_world(_rng, margin)
		if movement.body.global_position.distance_to(point) > movement.arrival_distance and _target_is_clear(point):
			movement.set_target(point)
			return true
	return false

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
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.transform.origin += point - movement.body.global_position
	query.collision_mask = movement.body.collision_mask
	query.exclude = [movement.body.get_rid()]
	return movement.body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
