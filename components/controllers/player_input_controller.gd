class_name PlayerInputController
extends Controller

@export var action_left: StringName = &"ui_left"
@export var action_right: StringName = &"ui_right"
@export var action_up: StringName = &"ui_up"
@export var action_down: StringName = &"ui_down"
@export var action_use_tool: StringName = &"use_tool"
@export var action_water: String = &"water"

func _physics_process(_delta: float) -> void:
	actor.movement_vector = Input.get_vector(action_left, action_right, action_up, action_down)

func _unhandled_key_input(event: InputEvent) -> void:
	var tool_action: String
	
	if event.is_action_pressed(action_use_tool):
		tool_action = "tool"
	if event.is_action_pressed(action_water):
		tool_action = "water"
	else:
		return
		
	var machine := actor.state_machine
	
	if not (machine.current_state is IdleState or machine.current_state is WalkState):
		return
	var tool_state = machine.get_node("ToolState") as ToolState
	tool_state.action = tool_action
	machine.change_state(&"tool")
	get_viewport().set_input_as_handled()
