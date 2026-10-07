class_name Player
extends CharacterBase

# if you want to define _ready(), you must have to call super._ready()

@onready var tool_state: ToolState = $StateMachine/ToolState


func use_tool(action: String) -> void:
	if not (state_machine.current_state is IdleState or state_machine.current_state is WalkState):
		return

	tool_state.action = action
	state_machine.change_state(&"tool")
