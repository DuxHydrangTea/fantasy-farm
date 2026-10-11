class_name FocusComponent
extends Area2D

signal focus_changed(focused: bool)

@onready var focus_marker: Node2D = $FocusMarker
@onready var pointer: Sprite2D = $FocusMarker/Pointer
@onready var _pointer_rest_position: Vector2 = pointer.position

@export var focus_enabled: bool = true
@export_range(0.0, 8.0) var bob_height: float = 3.0
@export_range(0.1, 1.0) var bob_duration: float = 0.35

var _focused: bool = false
var _bob_tween: Tween

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
	
	if _focused:
		_start_bobbing()
	else:
		_stop_bobbing()
	
	focus_changed.emit(_focused)

func _start_bobbing() -> void:
	_stop_bobbing()
	
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.set_trans(Tween.TRANS_SINE)
	_bob_tween.set_ease(Tween.EASE_IN_OUT)
	
	_bob_tween.tween_property(
		pointer,
		"position:y",
		_pointer_rest_position.y - bob_height,
		bob_duration
	)
	
	_bob_tween.tween_property(
		pointer,
		"position:y",
		_pointer_rest_position.y,
		bob_duration
	)
	
	
func _stop_bobbing() -> void:
	if _bob_tween != null:
		_bob_tween.kill()
		_bob_tween = null
	
	pointer.position = _pointer_rest_position
