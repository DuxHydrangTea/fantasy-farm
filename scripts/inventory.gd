class_name Inventory
extends Node2D

signal slot_changed(index: int)

const SLOT_COUNT = 16

var slots: Array[ItemSlot] = []

func _ready() -> void:
	for index in range(SLOT_COUNT):
		var slot := ItemSlot.new()
		slots.append(slot)
		slot.changed.connect(_on_slot_changed.bind(index))
		
func _on_slot_changed(index: int) -> void:
	slot_changed.emit(index)

func try_add_item(defination: ItemDefinition, amount: int) -> bool:
	if defination == null or amount <= 0:
		return false
		
	if defination.item_type != ItemDefinition.ItemType.PRODUCE:
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
