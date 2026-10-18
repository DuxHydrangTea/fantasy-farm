class_name HotbarView
extends MarginContainer

signal contents_changed

@onready var slots: HBoxContainer = $CenterContainer/Slots
@export var inventory: InventoryComponent

var selected_index: int = 0

func _ready() -> void:
	assert(inventory != null, "Hotbar chưa được gán InventoryComponent.")
	assert(slots.get_child_count() == 10, "Hotbar cần đúng 10 ô")
	assert(inventory.get_slot_count() >= 10, "Inventory cần ít nhất 10 ô")
	
	inventory.slots_changed.connect(_on_slots_changed)

	for index: int in range(slots.get_child_count()):
		var view: HotbarSlotView = slots.get_child(index) as HotbarSlotView
		assert(view != null, "Con của Slots phải là HotbarSlotView")
		view.setup(inventory, index)
	_refresh_items()
	select_slot(0)

func select_slot(index: int) -> void:
	if index < 0 or index >= slots.get_child_count():
		return
	
	selected_index = index
	
	for i: int in range(slots.get_child_count()):
		var slot: HotbarSlotView = slots.get_child(i) as HotbarSlotView
		assert(slot != null, "Con của slot phải là HotbarSlotView")
		slot.set_selected(i == selected_index)

func _refresh_items() -> void:
	for index: int in range(slots.get_child_count()):
		var view: HotbarSlotView = slots.get_child(index) as HotbarSlotView
		assert(view != null, "Con của Slots phải là HotbarSlotView")
		
		var slot: InventorySlot = inventory.get_slot(index)
		assert(slot != null, "Không tìm thấy ô inventory")
		
		view.set_item(slot.item, slot.amount)

func get_selected_item() -> ItemDefinition:
		var slot: InventorySlot = inventory.get_slot(selected_index)
		if slot == null or slot.is_empty():
			return null
		
		return slot.item

func _on_slots_changed() -> void:
	_refresh_items()
	contents_changed.emit()
