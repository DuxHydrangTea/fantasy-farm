class_name WalkState
extends State

@export var speed: float = 120.0

func enter() -> void:
	animation_component.update_facing_direction(actor.movement_vector)
	animation_component.play("walk")

func physics_update(_delta: float) -> void:
	if not actor.has_move_intent():
		state_machine.change_to_default()
		return
	
	animation_component.face(actor.movement_vector)
	movement_component.move(actor.movement_vector, _delta)
