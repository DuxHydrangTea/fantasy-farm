class_name TouchScrollGesture
extends RefCounted
## Scroll touch UI even on hybrid/preview devices, canceling the original button press.
var viewport: Viewport
var fingers: Dictionary[int, Dictionary] = {}

func handle(event: InputEvent) -> bool:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseMotion:
			return not fingers.is_empty()
		if event is InputEventMouseButton and not event.is_pressed():
			for finger: Dictionary in fingers.values():
				if finger.scrolling:
					return true
		return false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			var scroll: ScrollContainer = _find_scroll(viewport, touch.position)
			if scroll != null:
				for finger: Dictionary in fingers.values():
					if finger.scroll == scroll:
						return true
				fingers[touch.index] = {"scroll": scroll, "origin": _local(scroll, touch.position),
					"offset": Vector2(scroll.scroll_horizontal, scroll.scroll_vertical), "scrolling": false}
			return false
		if fingers.has(touch.index):
			var finger: Dictionary = fingers[touch.index]
			var consumed: bool = bool(finger.scrolling) or touch.canceled
			_end(finger, touch.canceled)
			fingers.erase(touch.index)
			return consumed
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if not fingers.has(drag.index):
			return false
		var finger: Dictionary = fingers[drag.index]
		var scroll: ScrollContainer = finger.scroll as ScrollContainer
		if not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
			fingers.erase(drag.index)
			return true
		var delta: Vector2 = _local(scroll, drag.position) - Vector2(finger.origin)
		if not finger.scrolling and delta.length() >= TouchGestureRouter.TAP_DISTANCE:
			finger.scrolling = true
			# BaseButton recognizes this notification and cancels its pending press.
			scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if finger.scrolling:
			var offset: Vector2 = Vector2(finger.offset) - delta
			if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				scroll.scroll_vertical = roundi(offset.y)
			if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				scroll.scroll_horizontal = roundi(offset.x)
		return true
	return false

func cancel() -> void:
	for finger: Dictionary in fingers.values():
		_end(finger, true)
	fingers.clear()

func _end(finger: Dictionary, canceled: bool) -> void:
	var scroll: ScrollContainer = finger.scroll as ScrollContainer
	if not is_instance_valid(scroll):
		return
	if canceled and not finger.scrolling:
		scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	if canceled or finger.scrolling:
		scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)

func _local(control: Control, point: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas().affine_inverse() * point

func _find_scroll(node: Node, point: Vector2) -> ScrollContainer:
	if node is Viewport and node != viewport:
		return null
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			return null
		if control.clip_contents and not Rect2(Vector2.ZERO, control.size).has_point(_local(control, point)):
			return null
	for child: Node in node.get_children():
		var found: ScrollContainer = _find_scroll(child, point)
		if found != null:
			return found
	if node is ScrollContainer:
		var scroll: ScrollContainer = node as ScrollContainer
		if Rect2(Vector2.ZERO, scroll.size).has_point(_local(scroll, point)):
			return scroll
	return null
