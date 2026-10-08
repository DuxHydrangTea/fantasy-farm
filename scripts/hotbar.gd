class_name Hotbar
extends HBoxContainer

signal slot_selected(index: int)

@export var slots: Array[ItemSlot] = []

var selected_index: int = -1
var _buttons: Array[Button] = []

func _ready() -> void:
	for index in range(slots.size()):
		var configuration_slot := slots[index]
		var runtime_slot := ItemSlot.new()
		
		if configuration_slot != null and not configuration_slot.is_empty():
			var success := runtime_slot.set_item(
				configuration_slot.item,
				configuration_slot.quantity
			)
			
			if not success:
				push_error("Hotbar: số lượng không hợp lệ ở slot %d" % index)
		
		slots[index] = runtime_slot
		
		var button = Button.new()
		button.custom_minimum_size = Vector2(48, 36)
		
		# Tránh nút giữ keyboard focus và nhận space
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(select_slot.bind(index))
		add_child(button)
		_buttons.append(button)
		
		runtime_slot.changed.connect(_refresh_slot.bind(index))
		_refresh_slot(index)
	if not slots.is_empty():
		select_slot(0)

func select_slot(index: int):
	if index < 0 or index >= slots.size():
		return
	
	if selected_index == index:
		return
		
	var previos_index := selected_index
	selected_index = index
	
	if previos_index >= 0:
		_refresh_slot(previos_index)
	
	_refresh_slot(selected_index)
	slot_selected.emit(selected_index)

func _refresh_slot(index: int):
	var slot := slots[index]
	var button := _buttons[index]
	
	button.icon = null
	button.text = ""
	button.tooltip_text = ""
	
	if not slot.is_empty():
		button.icon = slot.item.icon
		button.tooltip_text = slot.item.display_name

		if slot.item.item_type == ItemDefinition.ItemType.SEED:
			button.text = str(slot.quantity)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242832")
	style.set_border_width_all(2)
	style.border_color = Color("#ff3066") if index == selected_index else Color("#596170")
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)

func get_selected_slot() -> ItemSlot:
	if selected_index < 0 or selected_index >= slots.size():
		return null

	return slots[selected_index]
