class_name PlayerUIComponent
extends Node

signal inventory_open_changed(is_open: bool)

@export var hotbar: Hotbar
@export var inventory_panel: InventoryPanel
@export var inventory_button: BaseButton

@onready var actor: CharacterBase = get_parent() as CharacterBase

func _ready() -> void:
	assert(actor != null, "UIController phải nằm dưới nhân vật")
	assert(is_instance_valid(hotbar), "Chưa gán Hotbar")
	assert(
		is_instance_valid(inventory_panel),
		"Chưa gán InventoryPanel"
	)
	assert(
		is_instance_valid(inventory_button),
		"Chưa gán InventoryButton"
	)
	
	inventory_button.pressed.connect(toggle_inventory)
	inventory_panel.visibility_changed.connect(_on_inventory_visible_changed)
	
func toggle_inventory() -> void:
	if not is_inventory_open():
		if not (
			actor.state_machine.current_state is IdleState
			or actor.state_machine.current_state is WalkState
		):
			return
	inventory_panel.toggle()

func _on_inventory_visible_changed() -> void:
	var is_open := is_inventory_open()

	if is_open:
		actor.movement_vector = Vector2.ZERO
	
	inventory_open_changed.emit(is_open)

func is_inventory_open() -> bool:
	return inventory_panel.visible
	

func select_hotbar_slot(index: int) -> void:
	if is_inventory_open():
		return
	
	hotbar.select_slot(index)
