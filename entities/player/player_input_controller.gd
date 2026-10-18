class_name PlayerInputController
extends Node

const ACTION_UI_LEFT: StringName =  &"ui_left"
const ACTION_UI_RIGHT: StringName =  &"ui_right"
const ACTION_UI_UP: StringName =  &"ui_up"
const ACTION_UI_DOWN: StringName =  &"ui_down"

signal direction_changed(dir: Vector2)
signal tool_requested
signal hotbar_slot_selected(index: int)

var _dir := Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var dir_vector: Vector2 = Input.get_vector(
		ACTION_UI_LEFT,
		ACTION_UI_RIGHT,
		ACTION_UI_UP,
		ACTION_UI_DOWN
	)

	if _dir == dir_vector:
		return

	_dir = dir_vector
	direction_changed.emit(_dir)

func _unhandled_input(event: InputEvent) -> void:
	for index: int in range(10):
		var key_number: int = (index+1) % 10
		var action: StringName = StringName("hotbar_%d" % key_number)
		
		if event.is_action_pressed(action):
			hotbar_slot_selected.emit(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"use_item"):
		tool_requested.emit()
		get_viewport().set_input_as_handled()
