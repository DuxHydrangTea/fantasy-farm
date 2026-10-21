class_name BeehiveDefinition
extends Resource
## Tunable rules, shared assets and canonical outputs; no per-hive state here.
@export_range(1.0,604800.0) var cycle_seconds: float = 86400.0
@export_range(16.0,160.0) var radius: float = 80.0
@export_range(1.0,3.0) var pollen_speed: float = 1.3
@export_range(0.0,1.0) var crop_bonus: float = 0.1
@export_range(0.01,1.0) var specialty_ratio: float = 0.5
@export var wild_honey: ItemDefinition
@export var sunflower_honey: ItemDefinition
@export var floral_honey: ItemDefinition
@export var hive_item: ItemDefinition
@export var idle_texture: Texture2D
@export var full_texture: Texture2D

func honey_for(source: String) -> ItemDefinition:
	return wild_honey if source.is_empty() else sunflower_honey if source == "sunflower" else floral_honey
