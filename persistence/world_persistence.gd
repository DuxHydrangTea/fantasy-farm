class_name WorldPersistence
extends Node
## Only the real running MainWorld binds persistence. GUT/preview instances do not.
@export var world: FarmWorld
var _service: GameSaveManager
var _label: Label
var _hide_at: int = 0

func _ready() -> void:
	# A signal connection is removed if this preview is freed before the frame.
	# An awaiting coroutine instead resumes on a deleted instance during teardown.
	get_tree().process_frame.connect(_start, CONNECT_ONE_SHOT)

func _start() -> void:
	# Web startup can flush deferred calls before the main scene is assigned.
	# Wait one frame before applying the guard that keeps previews isolated.
	if get_tree().current_scene != world:
		return
	_service = SaveManager
	_build_notice()
	_service.status_changed.connect(_notice)
	await _service.bind_world(world)

func _build_notice() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	layer.add_child(margin)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	margin.add_child(_label)

func _notice(message: String, success: bool) -> void:
	_label.text = message
	_label.modulate = Color.WHITE if success else Color(1, 0.55, 0.4)
	_label.show()
	_hide_at = Time.get_ticks_msec() + (4000 if success else 15000)

func _process(_delta: float) -> void:
	if _label != null and Time.get_ticks_msec() > _hide_at:
		_label.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if _service == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		_service.save_game()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9:
		_service.load_game()
		get_viewport().set_input_as_handled()
