class_name FocusComponent
extends Area2D

signal focus_changed(focused: bool)

@export var focus_enabled: bool = true
@onready var focus_marker: Node2D = $FocusMarker
var _focused: bool = false

func _ready() -> void:
	focus_marker.hide()

func get_interaction_target() -> Node2D:
	return get_parent() as Node2D

func set_focused(value: bool) -> void:
	var next_focused := value and focus_enabled
	if _focused == next_focused:
		return
	_focused = next_focused
	focus_marker.visible = _focused
	focus_changed.emit(_focused)
