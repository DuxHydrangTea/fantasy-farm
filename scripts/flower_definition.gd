class_name FlowerDefinition
extends Resource
## Five growth stages, each with its own independent looping six-frame clip.
@export var flower_id: StringName
@export var display_name: String
@export var stage_frames: Array[SpriteFrames] = []
@export_range(1.0, 86400.0) var growth_seconds: float = 120.0
@export var harvest_item: ItemDefinition
@export_range(1, 99) var harvest_amount: int = 1

func is_valid() -> bool:
	return not flower_id.is_empty() and growth_seconds > 0.0 and stage_frames.size() == 5 and not stage_frames.has(null) and harvest_item != null
