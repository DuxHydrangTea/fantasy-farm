extends Label

@export var day_manager: DayManager

func _ready() -> void:
	assert(day_manager != null, "Chưa gán DayManager")
	day_manager.day_changed.connect(_on_day_changed)
	_on_day_changed(day_manager.current_day)
	
func _on_day_changed(current_day: int) -> void:
	text = "Ngày %d" % current_day
