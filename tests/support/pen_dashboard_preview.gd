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
	root.get_texture().get_image().save_png("res://../pen-" + label + ".png")

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.weather.set_debug_hour(12)
	world.tutorial.skip()
	await get_tree().create_timer(0.5).timeout
	var player: FarmPlayer = world.player
	_check(world.pen_boards.size() == 3, "All three pens have management signs")
	for board: PenBoard in world.pen_boards:
		player.global_position = board.global_position + Vector2(0, 24)
		player.animation.face(Vector2.UP)
		await get_tree().create_timer(0.25).timeout
		await _tap(player.mobile_controls.interact_button)
		_check(board.menu.is_open, "Native touch opens " + String(board.pen.name))
		_check(board.menu.cards.size() == PenStatus.members(board.pen).size(), "Board only lists its own animals")
		await _capture(String(board.pen.name) + "-en")
		await _tap(board.menu.close_button)
		_check(not player.selection.is_menu_open(), "Native close releases menu lock")
	var board: PenBoard = world.pen_boards[2]
	var animals: Array[AnimalActor] = PenStatus.members(board.pen)
	var actor: AnimalActor = animals[0]
	player.global_position = actor.global_position + Vector2(-24, 0)
	player.animation.face(Vector2.RIGHT)
	var state: AnimalBehaviourComponent.State = actor.behaviour.current_state
	var reservation: AnimalTrough = actor.foraging.target
	player.context_bars.refresh_at(actor.sprite.global_position)
	_check(actor.behaviour.current_state == state and actor.foraging.target == reservation, "Hover/focus never interrupts AI or meal reservation")
	_check(not actor.needs_display.visible, "Hover does not reveal world needs bars")
	for child: Node in player.context_bars.get_children():
		_check(not child is AnimalInfoPanel, "No automatic animal inspector exists")
	player.global_position = board.global_position + Vector2(0, 24)
	player.animation.face(Vector2.UP)
	await get_tree().create_timer(0.25).timeout
	await _tap(player.mobile_controls.interact_button)
	var menu: PenDashboard = board.menu
	var first: AnimalCard = menu.cards[animals[0].get_instance_id()]
	_check(first.preview != animals[0].sprite and first.preview.is_playing(), "Card uses its own animated idle sprite")
	var positions: Array[Vector2] = []
	for member: AnimalActor in animals:
		positions.append(member.global_position)
	await get_tree().create_timer(0.5).timeout
	var moved: bool = false
	for index: int in range(animals.size()):
		moved = moved or positions[index].distance_to(animals[index].global_position) > 0.1
	_check(moved, "World animals continue moving while dashboard is open")
	var start: Vector2 = _physical(menu.scroll)
	await _touch(0, start, true)
	for step: int in range(1, 9):
		await _drag(0, start - Vector2(0, step * 12))
	await _touch(0, start - Vector2(0, 96), false)
	_check(menu.scroll.scroll_vertical > 0, "Native swipe scrolls animal cards")
	Language.set_language("vi")
	menu.scroll.scroll_vertical = 0
	await _capture("PondPen-vi")
	for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
		DisplayServer.window_set_size(points)
		await get_tree().create_timer(0.35).timeout
		_check(menu.panel.size.x <= menu.root.size.x and menu.panel.size.y <= menu.root.size.y, "Dashboard fits phone safe area %s" % points)
		_check(menu.close_button.size.y >= 48 and menu.scroll.size.y >= 48, "Close and card area remain usable %s" % points)
		await _capture("phone-" + str(points.x))
	await _tap(menu.close_button)
	root.set_meta(&"touch_layout", false)
	root.set_meta(&"safe_insets", Vector4.ZERO)
	DisplayServer.window_set_size(Vector2i(500, 400))
	Language.set_language("en")
	await get_tree().create_timer(0.3).timeout
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.2).timeout
	_check(menu.is_open, "E opens pen management on desktop")
	_check(menu.panel.size.x <= menu.root.size.x and menu.panel.size.y <= menu.root.size.y, "Desktop 500x400 retains dashboard bounds")
	await _capture("desktop-500")
	key = InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.1).timeout
	_check(not menu.is_open, "Escape closes dashboard")
	var report: Dictionary = {"checks": checks, "failures": failures}
	var file: FileAccess = FileAccess.open("res://../pen-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
