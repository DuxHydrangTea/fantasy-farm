class_name Hotbar
extends HBoxContainer

signal slot_selected(index: int)

const SLOT_VIEW_SCENE: PackedScene = preload("res://scenes/item_slot_view.tscn")

@export var slots: Array[ItemSlot] = []

var selected_index: int = -1
var _buttons: Array[ItemSlotView] = []

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
		
		var button := SLOT_VIEW_SCENE.instantiate() as ItemSlotView
		
		# Tránh nút giữ keyboard focus và nhận space
		button.focus_mode = Control.FOCUS_NONE
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

func _refresh_slot(index: int) -> void:
	var slot: ItemSlot = slots[index]
	var button: ItemSlotView = _buttons[index]

	if index == selected_index:
		button.theme_type_variation = &"SelectedItemSlotButton"
	else:
		button.theme_type_variation = &"ItemSlotButton"

	button.display_slot(slot)

func get_selected_slot() -> ItemSlot:
	if selected_index < 0 or selected_index >= slots.size():
		return null

	return slots[selected_index]
	
func try_add_item(defination: ItemDefinition, amount: int) -> bool:
	if defination == null or amount <= 0:
		return false
		
	if defination.item_type == ItemDefinition.ItemType.PRODUCE:
		return false
	
	var stack_limit: int = defination.get_stack_limit()
	var capacity: int = 0
	
	for slot in slots:
		if slot == null:
			continue
		
		if slot.is_empty():
			capacity += stack_limit
		elif slot.item == defination:
			capacity += maxi(0, stack_limit - slot.quantity)
			
	if capacity < amount:
		return false
		
	var remaining: int = amount
	
	for slot in slots:
		if slot == null or slot.is_empty():
			continue
			
		if slot.item != defination:
			continue
			
		var available: int = maxi(0, stack_limit - slot.quantity)
		var added: int = mini(available, remaining)
		
		if added <=0:
			continue
			
		slot.quantity += added
		remaining -= added
		slot.emit_changed()
		
		if remaining == 0:
			return true
			
	for slot in slots:
		if slot == null:
			continue
		
		if not slot.is_empty():
			continue
			
		var added: int = mini(stack_limit, remaining)
		slot.set_item(defination, added)
		remaining -= added
		
		if remaining == 0:
			return true	
	return true
