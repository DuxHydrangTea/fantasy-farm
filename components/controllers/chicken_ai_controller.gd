class_name ChickenController
extends Controller

@export var wander_area: Area2D
@export_range(0.0, 32.0) var boundary_margin: float = 8.0
@onready var decision_timer: Timer = $Timer

var _boundary_shape: CollisionShape2D
var _walk_bounds: Rect2

func _ready() -> void:
	super._ready()
	assert(
		is_instance_valid(wander_area),
		"ChickenController: chưa gán WanderArea."
	)
	_boundary_shape = wander_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert(
		is_instance_valid(_boundary_shape),
		"WanderArea phải có node con CollisionShape2D."
	)
	var rectangle := _boundary_shape.shape as RectangleShape2D

	assert(
		rectangle != null,
		"WanderArea phải dùng RectangleShape2D."
	)

	var half_size := rectangle.size * 0.5
	_walk_bounds = Rect2(
		-half_size,
		rectangle.size
	).grow(-boundary_margin)

	assert(
		_walk_bounds.size.x > 0.0 and _walk_bounds.size.y > 0.0,
		"Boundary Margin quá lớn so với vùng di chuyển."
	)
	
	process_physics_priority = 10
	decision_timer.one_shot = true
	decision_timer.timeout.connect(_choose_behavior)
	decision_timer.start(1.0)

func _physics_process(_delta: float) -> void:
	_keep_inside_area()

func _choose_behavior() -> void:
	decision_timer.start(randf_range(2.0, 4.0))
	
	var current: State = actor.state_machine.current_state
	
	if not (current is WalkState or current is IdleState):
		return
	
	match randi_range(0, 4):
		0:
			actor.movement_vector = Vector2.ZERO
			actor.state_machine.change_state(&"idle")
		1:
			_start_wandering()
		2:
			actor.state_machine.change_state(&"peck")
		3:
			actor.state_machine.change_state(&"rest")
		4:
			actor.state_machine.change_state(&"sleep")

func _start_wandering() -> void:
	var angle := randf_range(0.0, TAU)
	actor.movement_vector = Vector2.from_angle(angle)
	actor.state_machine.change_state(&"walk")

func _keep_inside_area() -> void:
	var local_position := _boundary_shape.to_local(actor.global_position)
	var limited_position = Vector2(
		clampf(
			local_position.x,
			_walk_bounds.position.x,
			_walk_bounds.end.x
		),
		clampf(
			local_position.y,
			_walk_bounds.position.y,
			_walk_bounds.end.y
		)
	)

	if local_position.is_equal_approx(limited_position):
		return
	
	actor.global_position = _boundary_shape.to_global(limited_position)
	actor.movement_component.stop()
	
	if not (actor.state_machine.current_state is WalkState):
		actor.movement_vector = Vector2.ZERO
		return
	
	var direction := actor.movement_vector
	
	if local_position.x < _walk_bounds.position.x:
		direction.x = absf(direction.x)
	elif local_position.x > _walk_bounds.end.x:
		direction.x = -absf(direction.x)
	
	if local_position.y < _walk_bounds.position.y:
		direction.y = absf(direction.y)
	elif local_position.y > _walk_bounds.end.y:
		direction.y = -absf(direction.y)

	actor.movement_vector = direction.normalized()
	actor.animation_component.face(actor.movement_vector)	
