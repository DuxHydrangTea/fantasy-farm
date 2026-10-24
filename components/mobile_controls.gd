class_name MobileControls
extends CanvasLayer
## Touch input adapter. State/navigation/resolver own all gameplay decisions.
var player: FarmPlayer
var root: Control
var joystick: Control
var tool_button: Button
var interact_button: Button
var router: TouchGestureRouter = TouchGestureRouter.new()
var ui_scroll: TouchScrollGesture = TouchScrollGesture.new()
var zoom: CameraZoomComponent
var _hotbar: HotbarUI
var _active: bool = false
var _suspended: bool = false
var _last_size: Vector2
var _mode: int = 0 # Auto, on, off. Session only until Settings is implemented.
var _mouse_joystick: bool = false

func _ready() -> void:
	layer = 19
	ui_scroll.viewport = get_viewport()
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	UIScaleComponent.attach(self, root)
	joystick = Control.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.custom_minimum_size = Vector2(72, 72)
	root.add_child(joystick)
	joystick.draw.connect(_draw_joystick)
	tool_button = _button("Use")
	interact_button = _button("Interact")
	for child: Node in player.get_children():
		if child is CameraZoomComponent:
			zoom = child as CameraZoomComponent
		elif child is HotbarUI:
			_hotbar = child as HotbarUI
	router.movement_changed.connect(_movement_changed)
	router.action_requested.connect(_action_requested)
	router.tapped.connect(_tap)
	router.pinched.connect(_pinch)
	router.pinch_started.connect(player.state.cancel_input)
	player.selection.inventory_visibility_changed.connect(_menu_changed)
	player.selection.shop_visibility_changed.connect(_menu_changed)
	player.selection.objectives_visibility_changed.connect(_menu_changed)
	get_viewport().size_changed.connect(reset_input)
	root.resized.connect(_layout)
	_layout()
	_process(0.0)

func _button(caption: String) -> Button:
	var button: Button = Button.new()
	button.text = tr(caption)
	button.custom_minimum_size = Vector2(84, 48)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_disabled_color", Color(0.28, 0.18, 0.12, 0.55))
	button.clip_text = true
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var style: StyleBox = root.theme.get_stylebox(&"normal" if state == &"disabled" else state, &"Button").duplicate() as StyleBox
		style.set_content_margin(SIDE_LEFT, 4)
		style.set_content_margin(SIDE_RIGHT, 4)
		button.add_theme_stylebox_override(state, style)
	button.focus_mode = Control.FOCUS_NONE
	# Native touch IDs are handled here; emulated mouse must not press again.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(button)
	return button

func _layout() -> void:
	if joystick == null:
		return
	reset_input()
	_last_size = root.size
	joystick.size = Vector2(72, 72)
	joystick.position = Vector2(8, root.size.y - 84)
	tool_button.size = Vector2(84, 48)
	tool_button.position = Vector2(root.size.x - 92, root.size.y - 56)
	interact_button.size = Vector2(84, 48)
	interact_button.position = Vector2(root.size.x - 92, root.size.y - 110)
	router.joystick_center = joystick.position + joystick.size * 0.5
	joystick.queue_redraw()

func _process(_delta: float) -> void:
	var touch: bool = MobileLayout.is_touch(get_viewport()) if _mode == 0 else _mode == 1
	var portrait: bool = root.size.y > root.size.x
	var active: bool = touch and not portrait and not player.selection.is_menu_open() and not _suspended
	if active != _active:
		reset_input()
		_active = active
	root.visible = _active
	if _last_size != root.size:
		_layout()
	tool_button.text = tr("Use")
	interact_button.text = tr("Interact")
	var busy: bool = player.state.current_state in [StateComponent.State.TOOL, StateComponent.State.WATER]
	tool_button.disabled = busy or player.selection.get_selected_action().is_empty()
	var target: InteractionTarget = player.interactions.focused
	interact_button.disabled = busy or target == null or not target.valid()

func cycle_mode() -> void:
	_mode = (_mode + 1) % 3
	get_viewport().set_meta(&"touch_ui_override", _mode == 1)
	reset_input()

func mode_text() -> String:
	return tr("Touch controls: {mode}").format({"mode": tr(["Auto", "On", "Off"][_mode])})

func _input(event: InputEvent) -> void:
	if ui_scroll.handle(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION and _active:
		_mouse_input(event as InputEventMouse)
		return
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
		return
	# Handle release even if a modal appeared between touch-down and touch-up.
	if not _active:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var point: Vector2 = root.get_global_transform_with_canvas().affine_inverse() * touch.position
		if touch.pressed and not touch.canceled:
			var role: StringName = _role_at(point, touch.position)
			router.begin(touch.index, point, role)
			if role == &"ui":
				# Engine mouse emulation belongs to the first finger. A second finger
				# can still select a tool or open Bag while the joystick owns that first one.
				if router.joystick_id >= 0 and touch.index != router.joystick_id and _press_hotbar(touch.position):
					get_viewport().set_input_as_handled()
				return
		else:
			var role: StringName = router.fingers.get(touch.index, {}).get("role", &"ignored")
			router.end(touch.index, point, touch.canceled)
			if role == &"ui":
				return
	else:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		var role: StringName = router.fingers.get(drag.index, {}).get("role", &"ignored")
		router.drag(drag.index, root.get_global_transform_with_canvas().affine_inverse() * drag.position)
		if role == &"ui":
			return
	get_viewport().set_input_as_handled()

func _press_hotbar(point: Vector2) -> bool:
	if _hotbar == null or not _hotbar.root.visible:
		return false
	for index: int in range(_hotbar.buttons.size()):
		if _hits(_hotbar.buttons[index], point):
			player.selection.select_slot(index)
			return true
	if _hits(_hotbar.inventory_button, point):
		player.selection.set_inventory_open(true)
		return true
	return false

func _role_at(local: Vector2, viewport_point: Vector2) -> StringName:
	if _hits(joystick, viewport_point):
		return &"joystick"
	if _hits(tool_button, viewport_point):
		return &"ignored" if tool_button.disabled else &"tool"
	if _hits(interact_button, viewport_point):
		return &"ignored" if interact_button.disabled else &"interact"
	if _ui_at(get_viewport(), viewport_point):
		return &"ui"
	return &"world" if Rect2(Vector2.ZERO, root.size).has_point(local) else &"ignored"

func _hits(control: Control, point: Vector2) -> bool:
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO, control.size).has_point(control.get_global_transform_with_canvas().affine_inverse() * point)

func _ui_at(node: Node, point: Vector2) -> bool:
	if node == self or (node is SubViewport and node != get_viewport()):
		return false
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree() or (control.clip_contents and not _hits(control, point)):
			return false
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and _hits(control, point):
			return true
	for child: Node in node.get_children():
		if _ui_at(child, point):
			return true
	return false

func _movement_changed(direction: Vector2) -> void:
	player.state.touch_direction = direction
	joystick.queue_redraw()

func _mouse_input(event: InputEventMouse) -> void:
	var local: Vector2 = root.get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseMotion and _mouse_joystick:
		router.drag(-2, local)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if not click.pressed and _mouse_joystick:
			router.end(-2, local)
			_mouse_joystick = false
			get_viewport().set_input_as_handled()
		elif click.pressed:
			var role: StringName = _role_at(local, event.position)
			if role == &"joystick":
				_mouse_joystick = true
				router.begin(-2, local, role)
			elif role in [&"tool", &"interact"]:
				_action_requested(role)
			elif role == &"ignored":
				pass
			else:
				return
			get_viewport().set_input_as_handled()

func _action_requested(role: StringName) -> void:
	if not _active or player.selection.is_menu_open():
		return
	if role == &"tool":
		player.state.request_use()
	elif role == &"interact":
		player.state.request_interaction()

func _tap(point: Vector2) -> void:
	if _active and not player.selection.is_menu_open():
		var viewport_point: Vector2 = root.get_global_transform_with_canvas() * point
		player.state.click_world(player.get_canvas_transform().affine_inverse() * viewport_point)

func _pinch(ratio: float) -> void:
	if zoom != null and _active:
		zoom.pinch(ratio)

func _menu_changed(open: bool) -> void:
	if open:
		reset_input()
	_process(0.0)

func reset_input() -> void:
	_mouse_joystick = false
	ui_scroll.cancel()
	router.cancel()
	if is_instance_valid(player) and is_instance_valid(player.state):
		player.state.cancel_input()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_suspended = true
		if is_node_ready():
			reset_input()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_suspended = false

func _draw_joystick() -> void:
	var center: Vector2 = joystick.size * 0.5
	joystick.draw_circle(center, 35, Color(0.11, 0.17, 0.13, 0.72))
	joystick.draw_circle(center, 35, Color(0.91, 0.79, 0.53, 0.95), false, 2)
	joystick.draw_circle(center + router.direction * 20, 14, Color(0.93, 0.82, 0.59, 0.95))
