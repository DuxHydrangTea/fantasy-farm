class_name PlayerInputController
extends Controller

@export var action_left: StringName = &"ui_left"
@export var action_right: StringName = &"ui_right"
@export var action_up: StringName = &"ui_up"
@export var action_down: StringName = &"ui_down"
@export var action_use_item: StringName = &"use_item"
@export var action_toggle_inventory: StringName = &"toggle_inventory"

var player: Player

const HOTBAR_ACTIONS: Array[StringName] = [
	&"hotbar_1",
	&"hotbar_2",
	&"hotbar_3",
	&"hotbar_4",
	&"hotbar_5",
	&"hotbar_6",
	&"hotbar_7",
	&"hotbar_8",
	&"hotbar_9",
	&"hotbar_0",
]

func _ready() -> void:
	super._ready()
	player = actor as Player
	assert(player != null, "PlayerInputController phải là con trực tiếp của Player")

func _physics_process(_delta: float) -> void:
	if player.ui_controller.is_inventory_open():
		actor.movement_vector = Vector2.ZERO
		return

	actor.movement_vector = Input.get_vector(action_left, action_right, action_up, action_down)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	
	for index in range(HOTBAR_ACTIONS.size()):
		var action: StringName = HOTBAR_ACTIONS[index]
		
		if event.is_action_pressed(action):
			player.ui_controller.select_hotbar_slot(index)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(action_use_item):
		player.use_selected_item()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
		
	if not event.is_action_pressed(action_toggle_inventory):
		return
		
	player.ui_controller.toggle_inventory()
	get_viewport().set_input_as_handled()
