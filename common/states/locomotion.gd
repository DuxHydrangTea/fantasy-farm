class_name Locomotion
extends ActorState

@export var movement_component: MovementComponent
@export var facing_component: FacingComponent
@export var animation_component: AnimationComponent

func enter() -> void:
	super.enter()
	animation_component.set_facing(facing_component.facing_direction)

func _ready() -> void:
	assert(movement_component != null, "Locomotion thiếu MovementComponent.")
	assert(facing_component != null, "Locomotion thiếu FacingComponent.")
	assert(animation_component != null, "Locomotion thiếu AnimationComponent.")

func exit() -> void:
	movement_component.set_direction(Vector2.ZERO)
	animation_component.set_is_moving(false)
	super.exit()

func handle_direction(_dir: Vector2) -> void:
	movement_component.set_direction(_dir)
	facing_component.set_direction(_dir)
	animation_component.set_is_moving(not _dir.is_zero_approx())
