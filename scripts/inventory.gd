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

## return remaining
func add_item(defination: ItemDefinition, amount: int) -> int:
	if defination == null or amount <= 0:
		return 0
		
	if defination.item_type != ItemDefinition.ItemType.PRODUCE:
		return 0
	
	var stack_limit: int = defination.get_stack_limit()
	var remaining: int = amount
	
	for slot in slots:
		if slot == null or slot.is_empty() or slot.item != defination:
			continue
		
		var available: int = maxi(0, stack_limit - slot.quantity)
		var added: int = mini(available, remaining)
		if added > 0:
			slot.quantity += added
			remaining -= added
			slot.emit_changed()
			if remaining == 0:
				return 0
			
	# 2. Nếu vẫn còn dư, nhét vào các slot còn trống
	for slot in slots:
		if slot == null or not slot.is_empty():
			continue
			
		var added: int = mini(stack_limit, remaining)
		slot.set_item(defination, added)
		remaining -= added
		if remaining == 0:
			return 0	
			
	return remaining # Trả về số lượng còn thừa không nhét vừa

func try_add_item(
	definition: ItemDefinition,
	amount: int
) -> bool:
	if definition == null or amount <= 0:
		return false
		
	if definition.item_type != ItemDefinition.ItemType.PRODUCE:
		return false
		
	var stack_limit := definition.get_stack_limit()
	var capacity: int = 0
	
	for slot in slots:
		if slot == null:
			continue
			
		if slot.is_empty():
			capacity += stack_limit
		elif slot.item == definition:
			capacity += maxi(0, stack_limit - slot.quantity)
			
	if capacity < amount:
		return false
		
	return add_item(definition, amount) == 0
