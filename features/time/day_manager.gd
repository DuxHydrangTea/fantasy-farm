class_name DayManager
extends Node

signal day_changed(current_day: int)

@export_range(1.0, 3600.0, 1.0) var day_duration_seconds: float = 10.0
@onready var day_timer: Timer = $DayTimer

var current_day: int = 1

func _ready() -> void:
	day_timer.timeout.connect(advance_day)
	day_timer.start(day_duration_seconds)

func advance_day() -> void:
	current_day += 1
	day_timer.start(day_duration_seconds)
	day_changed.emit(current_day)
