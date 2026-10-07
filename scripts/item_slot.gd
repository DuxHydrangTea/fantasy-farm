class_name ItemSlot
extends Resource

@export var item: ItemDefinition
@export_range(0, 99) var quantity: int = 0

func is_empty() -> bool:
	return item == null or quantity <= 0

func set_item(definition: ItemDefinition, amount: int = 1) -> bool:
	if definition == null:
		return false
	
	if amount <= 0 or amount > definition.get_stack_limit():
		return false
	
	item = definition
	quantity = amount
	emit_changed()
	return true
	
func consume_seed(amount: int = 1) -> bool:
	if is_empty():
		return false
	
	if item.item_type != ItemDefinition.ItemType.SEED:
		return false
		
	if amount <= 0 or amount > quantity:
		return false
		
	quantity -= amount
	
	if quantity == 0:
		item = null
		
	emit_changed()
	return true
