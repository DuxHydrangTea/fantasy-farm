class_name FarmStorageDefinition
extends Resource
enum Kind { PRODUCE, SUPPLIES }
@export var storage_id: StringName
@export var display_name: String
@export var kind: Kind = Kind.PRODUCE
@export_range(1, 512) var slot_count: int = 128
@export_range(0, 32000) var stack_cap: int = 0

func accepts(item: ItemDefinition) -> bool:
	if item == null or item.item_id.is_empty():
		return false
	if kind == Kind.PRODUCE:
		return item.item_type == ItemDefinition.ItemType.PRODUCE
	return item.item_type == ItemDefinition.ItemType.FEED or (item.item_type == ItemDefinition.ItemType.SEED and item.crop is CropDefinition and item.crop.is_valid()) or (item.item_type == ItemDefinition.ItemType.BOOSTER and item.booster_kind in [ItemDefinition.BoosterKind.FERTILIZER, ItemDefinition.BoosterKind.PESTICIDE, ItemDefinition.BoosterKind.ANIMAL_MEDICINE])
