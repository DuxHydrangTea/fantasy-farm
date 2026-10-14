@tool
class_name ProgressBarDisplay
extends Control

@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		if is_node_ready():
			_update_color()
@export_range(0.0, 100.0) var progress_value: float = 0.0:
	set(value):
		progress_value = clampf(value, 0.0, 100.0)
		if is_node_ready():
			_update_progress_value()
@onready var bar: ProgressBar = $Frame/InnerMargin/ProgressBar
var _fill_style_box: StyleBoxFlat

func _ready() -> void:
	_fill_style_box = bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override("fill", _fill_style_box)
	_update_color()
	_update_progress_value()


func _update_color() -> void:
	_fill_style_box.bg_color = fill_color

func _update_progress_value() -> void:
	bar.value = progress_value
