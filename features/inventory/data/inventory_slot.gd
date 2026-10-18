class_name InventorySlot
extends RefCounted

var item: ItemDefinition
var amount: int = 0

func is_empty() -> bool:
	return item == null or amount <= 0
	
func clear() -> void:
	item = null
	amount = 0
