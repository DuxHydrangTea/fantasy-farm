class_name BeehiveDefinition
extends Resource
## Tunable rules, shared assets and canonical outputs; no per-hive state here.
@export_range(1.0,604800.0) var cycle_seconds: float = 86400.0
@export_range(16.0,160.0) var radius: float = 80.0
@export_range(1.0,3.0) var pollen_speed: float = 1.3
## Historic rate is retained only until a migrated batch is collected.
@export_range(1.0,3.0) var sunflower_speed: float = 4.0 / 3.0
@export_range(1.0,3.0) var floral_speed: float = 2.0
@export_range(1,32000) var batch_amount: int = 100
@export_range(0.0,1.0) var crop_bonus: float = 0.1
@export_range(0.01,1.0) var specialty_ratio: float = 0.5
@export var wild_honey: ItemDefinition
@export var sunflower_honey: ItemDefinition
@export var floral_honey: ItemDefinition
@export var hive_item: ItemDefinition
@export var idle_texture: Texture2D
@export var full_texture: Texture2D

func is_rare_flower(source: String) -> bool:
	return source in ["flower_06", "flower_07", "flower_08", "flower_09", "flower_10"]

func is_specialty(source: String) -> bool:
	return source == "sunflower" or is_rare_flower(source)

func honey_rate(source: String, legacy: bool = false) -> float:
	if legacy:
		return pollen_speed if not source.is_empty() else 1.0
	return sunflower_speed if source == "sunflower" else floral_speed if is_rare_flower(source) else 1.0

func honey_for(source: String, legacy: bool = false) -> ItemDefinition:
	return sunflower_honey if source == "sunflower" else floral_honey if (not source.is_empty() if legacy else is_rare_flower(source)) else wild_honey
