class_name ItemDefinition
extends Resource

enum ItemType {
	TOOL,
	SEED
}

enum ToolType {
	HOE,
	WATERING_CAN
}

@export var item_id: StringName
@export var display_name: String
@export var icon: Texture2D

@export var item_type: ItemType = ItemType.TOOL
@export var tool_type: ToolType = ToolType.HOE
@export var crop: CropDefinition

@export_range(1, 99) var max_stack: int = 99

func get_stack_limit() -> int:
	if item_type == ItemType.TOOL:
		return 1
	
	return max_stack
