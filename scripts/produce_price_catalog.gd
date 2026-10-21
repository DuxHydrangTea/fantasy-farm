class_name ProducePriceCatalog
extends Resource
@export var entries: Array[ProducePrice] = []

func is_valid() -> bool:
	var seen: Dictionary = {}
	for entry: ProducePrice in entries:
		if entry == null or not entry.is_valid() or seen.has(entry.item.item_id):
			return false
		seen[entry.item.item_id] = true
	return not entries.is_empty()

func find(item_id: StringName) -> ProducePrice:
	for entry: ProducePrice in entries:
		if entry != null and entry.is_valid() and entry.item.item_id == item_id:
			return entry
	return null
