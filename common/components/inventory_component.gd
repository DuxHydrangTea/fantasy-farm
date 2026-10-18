class_name InventoryComponent
extends Node

signal slots_changed
signal item_amount_changed(item_id: StringName, total: int)

@export var item_catalog: ItemCatalog
@export_range(10, 100, 1) var slot_count: int = 30

var _slots: Array[InventorySlot] = []

func _ready() -> void:
	assert(item_catalog != null, "Item Catalog chưa được gán")
	
	var catalog_valid := item_catalog.build_index()
	for index: int in range(slot_count):
		_slots.append(InventorySlot.new())
	assert(catalog_valid, "Build index cho Catalog thất bại")

func get_amount(item_id: StringName) -> int:
	var total: int = 0
	for slot: InventorySlot in _slots:
		if not slot.is_empty() and slot.item.item_id == item_id:
			total += slot.amount
	
	return total

func _find_add_slot(item_id: StringName) -> InventorySlot:
	var first_empty: InventorySlot = null
	
	for slot: InventorySlot in _slots:
		if slot.is_empty():
			if first_empty == null:
				first_empty = slot
		elif slot.item.item_id == item_id:
			return slot
	
	return first_empty

func add_item(item_id: StringName, amount: int) -> bool:
	if item_id == &"" or amount <= 0:
		return false
	
	var definition: ItemDefinition = item_catalog.get_item(item_id)
	if definition == null:
		return false
		
	var slot: InventorySlot = _find_add_slot(item_id)
	
	if slot == null: 
		return false
	
	slot.item = definition
	slot.amount += amount
	slots_changed.emit()
	item_amount_changed.emit(item_id, get_amount(item_id))
	return true

func get_item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: InventorySlot in _slots:
		if not slot.is_empty() and not ids.has(slot.item.item_id):
			ids.append(slot.item.item_id)
	return ids

func has_amount(item_id: StringName, amount: int = 1) -> bool:
	return item_id != &"" and amount > 0 and get_amount(item_id) >= amount
	
func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if not has_amount(item_id, amount):
		return false
	var remaining: int = amount
	
	for slot: InventorySlot in _slots:
		if slot.is_empty() or slot.item.item_id != item_id:
			continue
		
		var taken: int = mini(slot.amount, remaining)
		slot.amount -= taken
		remaining -= taken
		
		if slot.amount == 0:
			slot.clear()
			
		if remaining == 0:
			break
	
	slots_changed.emit()
	item_amount_changed.emit(item_id, get_amount(item_id))
	return true

func get_slot_count() -> int:
	return _slots.size()
	
func get_slot(index: int) -> InventorySlot:
	if index < 0 or index >= _slots.size():
		return null
	
	return _slots[index]

func move_or_swap_slot(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	
	var source: InventorySlot = get_slot(from_index)
	var target: InventorySlot = get_slot(to_index)
	
	if source == null or target == null:
		return false
	
	if source.is_empty():
		return false
	
	_slots[from_index] = target
	_slots[to_index] = source
	
	slots_changed.emit()
	return true
