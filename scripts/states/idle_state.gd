class_name IdleState
extends State

func enter() -> void:
	animation_component.play("idle")
	
func physics_update(_delta: float) -> void:
	movement_component.move(Vector2.ZERO, _delta)
	if actor.has_move_intent():
		state_machine.change_state(&"walk")
