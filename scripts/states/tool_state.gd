class_name ToolState
extends State

@export var action: String = "tool"

func enter() -> void:
	movement_component.stop()
	animation_component.action_finished.connect(_on_action_finished)
	animation_component.play(action, true)

func physics_update(_delta: float) -> void:
	movement_component.stop()

func _on_action_finished(finished_action: String) -> void:
	if state_machine.current_state != self:
		return
		
	if finished_action != action:
		return
		
	if actor.has_move_intent():
		state_machine.change_state(&"walk")
	else:
		state_machine.change_to_default()
		
func exit() -> void:
	animation_component.action_finished.disconnect(_on_action_finished)
