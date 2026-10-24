extends Node
## Run against the isolated Web staging project with a display. Never binds a save.
var world: FarmWorld
var failures: Array[String] = []
var checks: int = 0
var root: Window
var _points: Dictionary[int, Vector2] = {}

func _ready() -> void:
	root = get_tree().root
	root.set_meta(&"touch_layout", true)
	root.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
	DisplayServer.window_set_size(Vector2i(844, 390))
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _physical(control: Control) -> Vector2:
	return root.get_stretch_transform() * control.get_global_transform_with_canvas() * (control.size * 0.5)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	if pressed:
		_points[index] = point
	else:
		_points.erase(index)
	Input.parse_input_event(event)
	await get_tree().process_frame

func _drag(index: int, point: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = point - _points.get(index, point)
	event.screen_relative = event.relative
	_points[index] = point
	Input.parse_input_event(event)
	await get_tree().process_frame

func _tap(control: Control) -> void:
	var point: Vector2 = _physical(control)
	await _touch(0, point, true)
	await _touch(0, point, false)
	await get_tree().create_timer(0.1).timeout

func _capture(label: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../objectives-ui-" + label + ".png")

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.weather.set_debug_hour(12)
	await get_tree().create_timer(0.5).timeout
	var ui: ObjectiveUI = world.objective_ui
	await _tap(ui.hud_button)
	_check(ui.overlay.visible, "Native touch opens objective page")
	_check(not world.player.mobile_controls.joystick.is_visible_in_tree(), "Objective modal hides movement controls")
	await _capture("en")
	var start: Vector2 = _physical(ui.rows[1])
	await _touch(0, start, true)
	for step: int in range(1, 9):
		await _drag(0, start - Vector2(0, step * 10))
	await _touch(0, start - Vector2(0, 80), false)
	_check(ui.list_scroll.scroll_vertical > 0, "Native swipe scrolls objective list")
	_check(ui.inspected == 0, "Swipe does not activate another objective")
	world.objectives.progress.state_query = func(_condition: StringName) -> int: return 1
	world.objectives.progress.refresh_state()
	await _tap(ui.claim_button)
	_check(world.player.wallet.balance == 1025, "Native claim credits reward exactly once")
	await _tap(ui.claim_button)
	_check(world.player.wallet.balance == 1025, "Repeated claim does not duplicate reward")
	Language.set_language("vi")
	await _capture("vi")
	await _tap(ui.close_button)
	_check(not ui.overlay.visible, "Native touch closes objective page")
	_check(not world.player.state.navigation.has_focus, "Closing objective page does not navigate")
	await _tap(ui.collapse_button)
	_check(world.objectives.progress.hud_collapsed, "Native touch collapses HUD")
	await _capture("hud-vi")
	for size: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
		DisplayServer.window_set_size(size)
		await get_tree().create_timer(0.4).timeout
		await _tap(ui.hud_button)
		await get_tree().create_timer(0.2).timeout
		_check(ui.panel.size.x <= ui.root.size.x and ui.panel.size.y <= ui.root.size.y, "Page fits safe area %s" % size)
		_check(ui.claim_button.size.y >= 48 and ui.close_button.size.y >= 48, "Touch targets >=48 %s" % size)
		_check(ui.panel.get_global_rect().encloses(ui.claim_button.get_global_rect()), "Claim remains inside page %s" % size)
		await _capture("small-" + str(size.x))
		await _tap(ui.close_button)
	root.set_meta(&"touch_layout", false)
	root.set_meta(&"safe_insets", Vector4.ZERO)
	DisplayServer.window_set_size(Vector2i(500, 400))
	Language.set_language("en")
	world.objectives.progress.set_collapsed(false)
	await get_tree().create_timer(0.4).timeout
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.2).timeout
	_check(ui.overlay.visible, "J opens page at desktop 500x400")
	_check(ui.panel.get_global_rect().encloses(ui.claim_button.get_global_rect()), "Desktop small window keeps claim inside page")
	await _capture("desktop-500")
	key = InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.2).timeout
	_check(not ui.overlay.visible, "Escape closes objective page")
	await _capture("desktop-hud")
	var report: Dictionary = {"checks": checks, "failures": failures}
	var file: FileAccess = FileAccess.open("res://../objectives-ui-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
