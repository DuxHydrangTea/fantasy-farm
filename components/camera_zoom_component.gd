class_name CameraZoomComponent
extends Node
## Mouse-wheel camera zoom. UI gets first refusal through _unhandled_input.

@export var camera: Camera2D
@export var selection: ToolSelectionComponent
@export_range(0.1, 5.0, 0.05) var min_zoom: float = 1.0
@export_range(0.1, 5.0, 0.05) var max_zoom: float = 3.0
@export_range(1.01, 2.0, 0.01) var zoom_step: float = 1.15
@export_range(1.0, 30.0, 0.5) var zoom_speed: float = 12.0

var _target_zoom: float = 1.2

func _ready() -> void:
	assert(camera != null and selection != null, "Assign camera zoom references")
	_target_zoom = camera.zoom.x
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _minimum_zoom() -> float:
	# Camera limits constrain its center; zoom must also keep the view inside them.
	var map_size: Vector2 = Vector2(
		camera.limit_right - camera.limit_left,
		camera.limit_bottom - camera.limit_top
	)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var fit_zoom: float = maxf(
		view_size.x / maxf(map_size.x, 1.0),
		view_size.y / maxf(map_size.y, 1.0)
	)
	return maxf(min_zoom, fit_zoom)

func _clamp_zoom(value: float) -> float:
	var minimum: float = _minimum_zoom()
	return clampf(value, minimum, maxf(minimum, max_zoom))

func _on_viewport_size_changed() -> void:
	_target_zoom = _clamp_zoom(_target_zoom)
	# A larger viewport can immediately require a tighter view to avoid map edges.
	var value: float = _clamp_zoom(camera.zoom.x)
	camera.zoom = Vector2.ONE * value

func _unhandled_input(event: InputEvent) -> void:
	if selection.inventory_open:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom = _clamp_zoom(_target_zoom * zoom_step)
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom = _clamp_zoom(_target_zoom / zoom_step)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var value: float = lerpf(camera.zoom.x, _target_zoom, 1.0 - exp(-zoom_speed * delta))
	if is_equal_approx(value, _target_zoom):
		value = _target_zoom
	camera.zoom = Vector2.ONE * _clamp_zoom(value)
