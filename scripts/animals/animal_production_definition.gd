class_name AnimalProductionDefination
extends Resource
## Legacy resource class name retained for existing production definitions.
const Item = preload("res://scripts/item_definition.gd")
enum CollectionMode { WORLD_DROP, DIRECT_COLLECTION }
@export var production_item: Item
@export_range(1, 32000) var production_amount: int = 1
@export_range(1.0, 86400.0) var production_seconds: float = 1.0
@export var collection_mode: CollectionMode = CollectionMode.WORLD_DROP

func is_valid() -> bool:
	return production_item != null and production_item.item_type == Item.ItemType.PRODUCE and production_amount > 0 and production_seconds > 0.0
