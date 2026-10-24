class_name MobileLayout
extends RefCounted
## Screen measurements shared by HUDs. UI units on touch screens are CSS/device points.
static var _web_checked_at: int = -1000
static var _web: Dictionary = {}

static func _web_metrics() -> Dictionary:
	if OS.has_feature("web") and Time.get_ticks_msec() - _web_checked_at >= 100:
		_web_checked_at = Time.get_ticks_msec()
		var encoded: Variant = JavaScriptBridge.eval("window.FarmScreen ? JSON.stringify(window.FarmScreen.metrics()) : '{}'")
		var decoded: Variant = JSON.parse_string(str(encoded))
		_web = decoded if decoded is Dictionary else {}
	return _web

static func is_touch(viewport: Viewport) -> bool:
	if bool(viewport.get_meta(&"touch_ui_override", false)):
		return true
	if viewport.has_meta(&"touch_layout"):
		return bool(viewport.get_meta(&"touch_layout"))
	return bool(_web_metrics().get("touch", false)) if OS.has_feature("web") else OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

static func point_scale(viewport: Viewport) -> float:
	if viewport.has_meta(&"ui_point_scale"):
		return maxf(1.0, float(viewport.get_meta(&"ui_point_scale")))
	if OS.has_feature("web"):
		return maxf(1.0, float(_web_metrics().get("pixel_ratio", 1.0)))
	return maxf(1.0, DisplayServer.screen_get_scale()) if OS.has_feature("mobile") else 1.0

static func safe_insets(viewport: Viewport) -> Vector4:
	if viewport.has_meta(&"safe_insets"):
		return viewport.get_meta(&"safe_insets") as Vector4
	if not is_touch(viewport):
		return Vector4.ZERO
	if OS.has_feature("web"):
		var values: Array = _web_metrics().get("safe", [0, 0, 0, 0])
		return Vector4(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	var screen: Rect2i = DisplayServer.get_display_safe_area()
	var window: Rect2i = Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var safe: Rect2i = screen.intersection(window)
	if not safe.has_area():
		return Vector4.ZERO
	var scale: float = point_scale(viewport)
	return Vector4(safe.position.x - window.position.x, safe.position.y - window.position.y, window.end.x - safe.end.x, window.end.y - safe.end.y) / scale

static func prepare_buttons(node: Node) -> void:
	if node is BaseButton:
		var button: BaseButton = node as BaseButton
		button.custom_minimum_size = button.custom_minimum_size.max(Vector2(48, 48))
	for child: Node in node.get_children():
		prepare_buttons(child)
