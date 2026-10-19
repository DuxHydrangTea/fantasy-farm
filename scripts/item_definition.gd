class_name ItemDefinition
extends Resource

enum ItemType { TOOL, SEED, PRODUCE, FEED, HOE }
enum ToolType { HOE, WATERING_CAN }

@export var item_id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var show_world_quantity: bool = true
@export var item_type: ItemType = ItemType.TOOL
@export var tool_type: ToolType = ToolType.HOE
@export var crop: Resource
@export_range(1, 32000) var max_stack: int = 99
@export_range(1, 32000) var food_units_per_item: int = 300

func get_stack_limit() -> int:
	return 1 if item_type == ItemType.TOOL or item_type == ItemType.HOE else maxi(1, max_stack)

func matches(other: Resource) -> bool:
	return other is ItemDefinition and not item_id.is_empty() and item_id == other.item_id
