class_name TreeDefinition
extends Resource
## Dữ liệu dùng chung; không chứa trạng thái của từng cây đã trồng.
enum Kind { FRUIT, TIMBER }
@export var tree_id: StringName
@export var display_name: String
@export var kind: Kind = Kind.FRUIT
@export var growth_seconds: float = 180.0
@export var fruit_cycle_seconds: float = 90.0
@export var stump_seconds: float = 120.0
@export var chop_hits: int = 4
@export var dig_hits: int = 1
@export var harvest_amount: int = 3
@export var star_harvest_item: ItemDefinition
@export var harvest_item: ItemDefinition
@export var root_item: ItemDefinition
@export var stage_textures: Array[Texture2D] = []
@export var ready_texture: Texture2D
@export var stump_texture: Texture2D
@export var canopy_texture: Texture2D
@export var leaf_texture: Texture2D

func planting_item() -> ItemDefinition:
	var path: String = "res://items/trees/%s_sapling.tres" % tree_id
	return load(path) as ItemDefinition

func is_valid() -> bool:
	return not tree_id.is_empty() and growth_seconds > 0.0 and fruit_cycle_seconds > 0.0 and stump_seconds > 0.0 and chop_hits > 0 and dig_hits > 0 and harvest_amount > 0 and harvest_item != null and stage_textures.size() == 3 and not stage_textures.has(null) and ready_texture != null and (kind == Kind.FRUIT or (root_item != null and stump_texture != null and canopy_texture != null))
