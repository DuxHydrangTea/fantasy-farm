class_name PlayerInputController
extends Controller

@export var action_left: StringName = &"ui_left"
@export var action_right: StringName = &"ui_right"
@export var action_up: StringName = &"ui_up"
@export var action_down: StringName = &"ui_down"

func _physics_process(_delta: float) -> void:
	actor.movement_vector = Input.get_vector(action_left, action_right, action_up, action_down)
