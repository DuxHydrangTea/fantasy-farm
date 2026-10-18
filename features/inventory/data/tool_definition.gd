class_name ToolDefinition
extends ItemDefinition

@export_enum("tool", "water") var action: String = "tool"

func is_valid() -> bool:
	if not super.is_valid():
		return false
	
	return action == "tool" or action == "water"
