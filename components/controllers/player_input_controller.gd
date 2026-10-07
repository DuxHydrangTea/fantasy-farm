class_name PlayerInputController
extends Controller

@export var action_left: StringName = &"ui_left"
@export var action_right: StringName = &"ui_right"
@export var action_up: StringName = &"ui_up"
@export var action_down: StringName = &"ui_down"
@export var action_use_tool: StringName = &"use_tool"
@export var action_water: StringName = &"water"

var player: Player

func _ready() -> void:
	super._ready()
	player = actor as Player
	assert(player != null, "PlayerInputController phải là con trực tiếp của Player")

func _physics_process(_delta: float) -> void:
	actor.movement_vector = Input.get_vector(action_left, action_right, action_up, action_down)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(action_use_tool):
		player.use_tool("tool")
	elif event.is_action_pressed(action_water):
		player.use_tool("water")
	else:
		return

	get_viewport().set_input_as_handled()
