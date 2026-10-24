class_name OrderCatalog
extends Resource
@export var entries: Array[OrderDefinition] = []
## Retired requests remain deliverable with their original quantities and reward.
@export var legacy_catalog: Resource

func find(id: StringName) -> OrderDefinition:
	for entry: OrderDefinition in entries:
		if entry != null and entry.order_id == id:
			return entry
	return (legacy_catalog as OrderCatalog).find(id) if legacy_catalog is OrderCatalog else null

func is_valid() -> bool:
	var seen: Dictionary = {}
	for entry: OrderDefinition in entries:
		if entry == null or not entry.is_valid() or seen.has(entry.order_id):
			return false
		seen[entry.order_id] = true
	return not entries.is_empty()
