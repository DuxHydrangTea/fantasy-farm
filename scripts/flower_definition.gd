class_name FlowerDefinition
extends Resource
## Five static textures, one for each growth stage.
@export var flower_id: StringName
@export var display_name: String
@export var stage_textures: Array[Texture2D] = []
@export_range(1.0, 86400.0) var growth_seconds: float = 120.0
@export var harvest_item: ItemDefinition
@export_range(1, 99) var harvest_amount: int = 1

func is_valid() -> bool:
	return not flower_id.is_empty() and growth_seconds > 0.0 and stage_textures.size() == 5 and not stage_textures.has(null) and harvest_item != null
