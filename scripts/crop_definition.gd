class_name CropDefinition
extends Resource
@export var crop_id: StringName
@export var stage_textures: Array[Texture2D] = []
@export var growth_seconds: float = 1200.0
@export var harvest_item: Resource
@export var harvest_amount: int = 1

func is_valid() -> bool:
	return growth_seconds > 0.0 and stage_textures.size() == 4 and not stage_textures.has(null)

func has_valid_harvest() -> bool:
	return harvest_item is ItemDefinition and harvest_item.item_type == ItemDefinition.ItemType.PRODUCE and harvest_amount > 0
