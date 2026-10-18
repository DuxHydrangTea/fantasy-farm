class_name ItemDefinition
extends Resource

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

func is_valid() -> bool:
	if item_id == &"" or display_name == "" or icon == null:
		return false
	return true
