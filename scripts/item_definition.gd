@tool
class_name ItemDefinition
extends Resource

enum ItemType {
	TOOL,
	SEED,
	PRODUCE,
	FEED,
	HOE
}

enum ToolType {
	HOE,
	WATERING_CAN
}

@export var item_id: StringName
@export var display_name: String
@export var icon: Texture2D

@export var item_type: ItemType = ItemType.TOOL:
	set(value):
		if item_type == value:
			return
		
		item_type = value
		notify_property_list_changed()
@export var tool_type: ToolType = ToolType.HOE
@export var crop: CropDefinition
@export_range(1, 32000) var max_stack: int = 99
@export_range(1, 32000) var food_units_per_item: int = 300

func get_stack_limit() -> int:
	if item_type == ItemType.TOOL:
		return 1
	
	return max_stack
	
func _validate_property(property: Dictionary) -> void:
	var should_hide := false

	match property["name"]:
		"tool_type":
			should_hide = item_type != ItemType.TOOL
		"crop":
			should_hide = item_type != ItemType.SEED
		"food_units_per_item":
			should_hide = item_type != ItemType.FEED

	if should_hide:
		property["usage"] = (
			int(property["usage"]) & ~PROPERTY_USAGE_EDITOR
		)
