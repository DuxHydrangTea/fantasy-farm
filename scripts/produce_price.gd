class_name ProducePrice
extends Resource
@export var item: ItemDefinition
@export_range(1, 1000000) var price: int = 1

func is_valid() -> bool:
	return item != null and not item.item_id.is_empty() and item.item_type == ItemDefinition.ItemType.PRODUCE and price >= 1 and price <= 1000000
