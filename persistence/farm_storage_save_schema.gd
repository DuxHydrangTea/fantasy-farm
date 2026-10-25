class_name FarmStorageSaveSchema
extends RefCounted
const DEFINITIONS: Dictionary = {
	"produce_warehouse": preload("res://resources/storage/produce_warehouse.tres"),
	"farm_supply_storage": preload("res://resources/storage/farm_supply_storage.tres")
}

static func fresh() -> Dictionary:
	var result: Dictionary = {}
	for id: String in DEFINITIONS:
		var definition: FarmStorageDefinition = DEFINITIONS[id]
		var slots: Array = []
		for i: int in range(definition.slot_count):
			slots.append({"item": "", "count": 0, "tiers": [0, 0, 0]})
		result[id] = {"slot_count": definition.slot_count, "stack_cap": definition.stack_cap, "slots": slots}
	return result

static func valid(data: Variant, catalog: SaveCatalog) -> bool:
	if not data is Dictionary or data.size() != DEFINITIONS.size():
		return false
	for id: String in DEFINITIONS:
		var row: Variant = data.get(id)
		if not row is Dictionary or row.size() != 3 or not SaveSchema.number(row.get("slot_count"), 1, 512, true) or not SaveSchema.number(row.get("stack_cap"), 0, 32000, true) or not row.get("slots") is Array or row.slots.size() != int(row.slot_count):
			return false
		var definition: FarmStorageDefinition = DEFINITIONS[id]
		for slot: Variant in row.slots:
			if not QualitySaveSchema.slot_valid(slot, catalog, int(row.stack_cap)):
				return false
			if slot.item.is_empty():
				if slot.count != 0:
					return false
				continue
			var item: ItemDefinition = catalog.items.get(slot.item) as ItemDefinition
			if not definition.accepts(item) or slot.count < 1:
				return false
			var limit: int = mini(item.get_stack_limit(), int(row.stack_cap)) if row.stack_cap > 0 else item.get_stack_limit()
			if slot.count > limit:
				return false
	return true
