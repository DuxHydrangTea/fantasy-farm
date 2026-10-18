class_name DebugDayAdvance
extends Node

@export var day_manager: DayManager

func _ready() -> void:
	assert(day_manager != null, "Chưa gán DayManager")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"debug_advance_day"):
		return
	
	day_manager.advance_day()
	print("Ngày hiện tại: ", day_manager.current_day)
	get_viewport().set_input_as_handled()
