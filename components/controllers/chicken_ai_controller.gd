class_name ChickenController
extends Controller

@export var wander_area: Area2D
@export var coop: ChickenCoop
@export_range(0.0, 32.0) var boundary_margin: float = 8.0
@export_range(1.0, 16.0) var arrival_distance: float = 3.0

@onready var decision_timer: Timer = $Timer
@onready var needs_component: LegacyAnimalNeedsComponent = $"../AnimalNeedsComponent"

var _boundary_shape: CollisionShape2D
var _walk_bounds: Rect2
var _target_point: Marker2D
var _target_need: NeedKind = NeedKind.NONE
var _arrived: bool = false

enum NeedKind {
	NONE,
	FOOD,
	WATER	
}

func _ready() -> void:
	super._ready()
	assert(
		is_instance_valid(coop),
		"ChickenController: chưa gán ChickenCoop."
	)
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
	
	if _target_need == NeedKind.NONE:
		return
	
	if not is_instance_valid(_target_point):
		_cancel_seeking()
		return
	
	if _arrived:
		return
	
	var target_position := _target_point.global_position
	var distance := actor.global_position.distance_to(target_position)
	
	var stop_distance := maxf(
		arrival_distance,
		actor.movement_component.speed * _delta
	)
	
	if distance <= stop_distance:
		_arrived = true
		actor.movement_vector = Vector2.ZERO
		actor.movement_component.stop()
		actor.state_machine.change_state(&"idle")
		
		print(actor.name, " | Đã tới điểm ăn/uống")
		return
		
	actor.movement_vector = actor.global_position.direction_to(target_position)

func _cancel_seeking() -> void:
	_target_point = null
	_target_need = NeedKind.NONE
	_arrived = false
	actor.movement_vector = Vector2.ZERO
	actor.animation_component.stop()
	actor.state_machine.change_state(&"idle")

func _choose_behavior() -> void:
	decision_timer.start(randf_range(2.0, 4.0))
	
	
	if _target_need != NeedKind.NONE:
		return
		
	var current: State = actor.state_machine.current_state
	
	if not (current is WalkState or current is IdleState):
		return
	
	var priority_need := _get_priority_need()
	
	var chicken := actor as Chicken
	
	if chicken == null or chicken.definition == null:
		return
	
	match  priority_need:
		NeedKind.NONE:
			print(actor.name, " | Chưa cần tìm máng!")
		NeedKind.FOOD:
			var food_target := coop.find_nearest_feed_trough(
				actor.global_position,
				chicken.definition
			)

			if food_target != null:
				if _begin_seeking(food_target.eat_point, NeedKind.FOOD):
					return

		NeedKind.WATER:
			var water_target := coop.find_nearest_water_trough(
				actor.global_position,
				chicken.definition
			)

			if water_target != null:
				if _begin_seeking(water_target.drink_point, NeedKind.WATER):
					return
				
	
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

func _get_priority_need() -> NeedKind:
	if not needs_component.is_initialized():
		return NeedKind.NONE
	
	var hungry := needs_component.is_hungry()
	var thirsty := needs_component.is_thirsty()
	
	if hungry and thirsty:
		if needs_component.hydration <= needs_component.satiety:
			return NeedKind.WATER
		return NeedKind.FOOD
	
	if thirsty:
		return NeedKind.WATER
	
	if hungry:
		return NeedKind.FOOD
	
	return NeedKind.NONE

func _begin_seeking(point: Marker2D, need: NeedKind) -> bool:
	if not is_instance_valid(point):
		return false
	
	var local_point := _boundary_shape.to_local(point.global_position)
	
	if not _walk_bounds.has_point(local_point):
		push_warning("Điểm ăn/uống nằm ngoài vùng gà được đi.")
		return false
		
	_target_point = point
	_target_need = need
	_arrived = false
	
	actor.movement_vector = actor.global_position.direction_to(point.global_position)
	actor.state_machine.change_state(&"walk")
	return true
