class_name UIScaleComponent
extends Node
## Canvas-only scale: keep UI readable when the world viewport shrinks to a small window.
## Roots use virtual coordinates; engine input follows the same CanvasLayer transform.
signal layout_changed(virtual_size: Vector2)
const MINIMUM_VIEW: Vector2 = Vector2(640, 360)
var canvas: CanvasLayer
var root: Control
var _last_view_size: Vector2
var _last_screen_scale: Vector2
var _last_insets: Vector4
var _last_point_scale: float = 1.0
var _last_touch: bool = false

static func attach(layer: CanvasLayer, control: Control) -> UIScaleComponent:
	var component: UIScaleComponent = UIScaleComponent.new()
	component.canvas = layer
	component.root = control
	component.name = "UIScale"
	layer.add_child(component)
	return component

func _ready() -> void:
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(refresh)
	refresh()
	# Stretch/DPI can change without a logical viewport resize.
	var fallback: Timer = Timer.new()
	fallback.wait_time = 0.1
	fallback.timeout.connect(_check_stretch)
	add_child(fallback)
	fallback.start()

func _check_stretch() -> void:
	var viewport: Viewport = get_viewport()
	var view_changed: bool = not _last_view_size.is_equal_approx(viewport.get_visible_rect().size)
	var scale_changed: bool = not _last_screen_scale.is_equal_approx(viewport.get_stretch_transform().get_scale().abs())
	var safe_changed: bool = _last_insets != MobileLayout.safe_insets(viewport)
	var mode_changed: bool = _last_touch != MobileLayout.is_touch(viewport) or not is_equal_approx(_last_point_scale, MobileLayout.point_scale(viewport))
	if view_changed or scale_changed or safe_changed or mode_changed:
		refresh()

func refresh() -> void:
	var viewport: Viewport = get_viewport()
	var mode_changed: bool = _last_touch != MobileLayout.is_touch(viewport)
	var view: Vector2 = viewport.get_visible_rect().size
	var screen_scale: Vector2 = viewport.get_stretch_transform().get_scale().abs()
	_last_view_size = view
	_last_screen_scale = screen_scale
	_last_touch = MobileLayout.is_touch(viewport)
	_last_insets = MobileLayout.safe_insets(viewport)
	_last_point_scale = MobileLayout.point_scale(viewport)
	var stretch: float = maxf(0.001, minf(screen_scale.x, screen_scale.y))
	var factor: float = maxf(1.0, minf(1.0 / stretch, minf(view.x / MINIMUM_VIEW.x, view.y / MINIMUM_VIEW.y)))
	if _last_touch:
		factor = _last_point_scale / stretch
	var virtual_size: Vector2 = view / factor
	var origin: Vector2 = Vector2(_last_insets.x, _last_insets.y)
	virtual_size -= origin + Vector2(_last_insets.z, _last_insets.w)
	virtual_size = virtual_size.max(Vector2.ONE)
	if canvas.scale.is_equal_approx(Vector2.ONE * factor) and root.size.is_equal_approx(virtual_size) and root.position.is_equal_approx(origin):
		if mode_changed:
			root.resized.emit()
			layout_changed.emit(virtual_size)
		return
	canvas.scale = Vector2.ONE * factor
	root.position = origin
	root.size = virtual_size
	layout_changed.emit(virtual_size)
