class_name CameraZoomComponent
extends Node
## Mouse-wheel camera zoom. UI gets first refusal through _unhandled_input.

@export var camera: Camera2D
@export var selection: ToolSelectionComponent
@export_range(0.1, 5.0, 0.05) var min_zoom: float = 1.0
@export_range(0.1, 12.0, 0.1) var max_zoom: float = 8.0
@export_range(1.01, 2.0, 0.01) var zoom_step: float = 1.15
@export_range(1.0, 30.0, 0.5) var zoom_speed: float = 12.0

var _target_zoom: float = 1.2
var _last_limits: Rect2i
var _last_min_zoom: float
var _last_max_zoom: float

func _ready() -> void:
	assert(camera != null and selection != null, "Assign camera zoom references")
	_target_zoom = camera.zoom.x
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	# Camera2D has no signal for limits changed by scripts/inspector.
	var constraints_timer: Timer = Timer.new()
	constraints_timer.wait_time = 0.1
	constraints_timer.timeout.connect(_check_constraints)
	add_child(constraints_timer)
	constraints_timer.start()

func _limits() -> Rect2i:
	return Rect2i(camera.limit_left, camera.limit_top,
		camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)

func _check_constraints() -> void:
	if _last_limits != _limits() or _last_min_zoom != min_zoom or _last_max_zoom != max_zoom:
		_on_viewport_size_changed()

# Zoom càng lớn thì phần thế giới nhìn thấy càng nhỏ: kích thước nhìn được = viewport / zoom.
# Muốn không thấy ngoài map phải có zoom >= viewport_rộng/map_rộng và tương tự chiều cao;
# lấy max của hai tỷ lệ để thỏa cả hai. Giới hạn Camera2D một mình chưa giải quyết trường hợp
# viewport lớn hơn map. Nếu bỏ phép tính này, thu nhỏ zoom/đổi cửa sổ có thể lộ khoảng trống.
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
	_last_limits = _limits()
	_last_min_zoom = min_zoom
	_last_max_zoom = max_zoom
	_target_zoom = _clamp_zoom(_target_zoom)
	# A larger viewport can immediately require a tighter view to avoid map edges.
	var value: float = _clamp_zoom(camera.zoom.x)
	camera.zoom = Vector2.ONE * value
	set_process(not is_equal_approx(value, _target_zoom))

func _unhandled_input(event: InputEvent) -> void:
	if selection.is_menu_open():
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
	set_process(true)
	get_viewport().set_input_as_handled()

# Hệ số nội suy a = 1 - exp(-k * delta) làm khoảng cách tới zoom đích giảm theo hàm mũ.
# Với đích cố định, sau cùng một khoảng thời gian, mức tiến gần đích gần như không phụ thuộc FPS.
# Lerp với một hệ số cố định mỗi frame sẽ nhanh hơn trên máy FPS cao; k*delta còn có thể
# vượt 1 khi bị khựng. Đây chỉ là làm mượt: có thể gán thẳng zoom đích nếu không muốn hiệu ứng.
func _process(delta: float) -> void:
	var value: float = lerpf(camera.zoom.x, _target_zoom, 1.0 - exp(-zoom_speed * delta))
	if is_equal_approx(value, _target_zoom):
		value = _target_zoom
	camera.zoom = Vector2.ONE * _clamp_zoom(value)
	if is_equal_approx(camera.zoom.x, _target_zoom):
		set_process(false)
