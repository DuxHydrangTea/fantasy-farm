class_name GameDebugPanel
extends PanelContainer

const WHEAT_PRODUCE: ItemDefinition = preload("res://items/harvest_produces/wheat_produces.tres")

@export var inventory: Inventory

@onready var actions_container: VBoxContainer = $MarginContainer/VBoxContainer/Actions
@onready var status_label: Label = $MarginContainer/VBoxContainer/Status

var actions: Array[Dictionary] = [
	{
		"text": "+10.000 wheat",
		"callback": _add_item.bind(WHEAT_PRODUCE, 10_000)
	}
]

func _ready() -> void:
	if not OS.is_debug_build():
		hide()
		return
	
	if not is_instance_valid(inventory):
		status_label.text = "Chưa gán Inventory"
		return
		
	if not inventory.is_node_ready():
		await  inventory.ready
	
	_create_action_buttons()

func _create_action_buttons() -> void:
	for action in actions:
		var button := Button.new()
		button.text = action["text"]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		button.add_theme_font_size_override(&"font_size", 6)
		button.pressed.connect(action["callback"])
		actions_container.add_child(button)
	
func _add_item(definition: ItemDefinition, amount: int) -> void:
	if not is_instance_valid(inventory):
		return
	
	var remaining := inventory.add_item(definition, amount)
	
	if remaining == 0:
		status_label.text = "Thêm thành công"
	elif remaining > 0:
		status_label.text = "Thêm thành công nhưng không đủ chỗ"
	else:
		status_label.text = "Thêm thất bại"
