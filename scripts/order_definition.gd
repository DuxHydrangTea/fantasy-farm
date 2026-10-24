class_name OrderDefinition
extends Resource
## Authored request; saves store only its stable ID, never paths or prices.
@export var order_id: StringName
@export var title: String
@export var items: Array[ItemDefinition] = []
@export var amounts: Array[int] = []
@export var reward_coins: int = 1

func is_valid() -> bool:
	if order_id.is_empty() or title.is_empty() or items.is_empty() or items.size() > 2 or amounts.size() != items.size() or reward_coins <= 0:
		return false
	var seen: Dictionary = {}
	for index: int in range(items.size()):
		var item: ItemDefinition = items[index]
		if item == null or item.item_type != ItemDefinition.ItemType.PRODUCE or item.item_id.is_empty() or seen.has(item.item_id) or amounts[index] < 1 or amounts[index] > 32000:
			return false
		seen[item.item_id] = true
	return true
