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
	root.get_texture().get_image().save_png("res://../orders-" + label + ".png")

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.weather.set_debug_hour(12)
	var player: FarmPlayer = world.player
	player.global_position = world.orders.global_position + Vector2(0, 24)
	player.animation.face(Vector2.UP)
	await get_tree().create_timer(0.6).timeout
	var ui: OrderUI = world.orders.menu
	var orders: OrderService = world.orders.service
	_check(player.interactions.resolver.resolve().node == world.orders, "Board has a reachable separate approach")
	await _capture("board-en")
	await _tap(player.mobile_controls.interact_button)
	_check(ui.is_open, "Native touch context opens order board")
	await _capture("page-en")
	var serial: int = ui.selected_serial
	var entry: OrderDefinition = orders.definition(serial)
	orders.inventory.add(entry.items[0], entry.amounts[0])
	await _tap(ui.deliver_button)
	_check(ui.confirmation.visible, "Native delivery requires confirmation")
	_check(ui.panel.size.y <= ui.root.size.y, "Confirmation fits phone height")
	_check(ui.panel.get_global_rect().encloses(ui.confirm_button.get_global_rect()), "Confirm button remains inside panel")
	_check(player.wallet.balance == 1000, "Requesting confirmation does not spend items or credit coins")
	await _capture("confirm-en")
	await _tap(ui.cancel_button)
	_check(not ui.confirmation.visible and player.wallet.balance == 1000, "Cancel keeps state unchanged")
	await _tap(ui.deliver_button)
	await _tap(ui.confirm_button)
	_check(player.wallet.balance == 1072 and orders.capture().completed == 1, "Native confirmation delivers exactly once")
	ui.rows[0].pressed.emit()
	await _tap(ui.abandon_button)
	Language.set_language("vi")
	await get_tree().create_timer(0.1).timeout
	_check(ui.panel.size.y <= ui.root.size.y, "Vietnamese confirmation fits phone height")
	await _capture("confirm-vi")
	var before: int = player.wallet.balance
	await _tap(ui.confirm_button)
	_check(player.wallet.balance == before, "Native abandon has no coin penalty or reward")
	await _capture("page-vi")
	await _tap(ui.close_button)
	_check(not player.selection.is_menu_open(), "Native close releases modal lock")
	_check(not player.state.navigation.has_focus, "Closing page does not click through")
	for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
		DisplayServer.window_set_size(points)
		await get_tree().create_timer(0.4).timeout
		world.orders.open_board(player)
		await get_tree().create_timer(0.1).timeout
		_check(ui.panel.size.x <= ui.root.size.x and ui.panel.size.y <= ui.root.size.y, "Panel fits phone safe area %s" % points)
		_check(ui.panel.get_global_rect().encloses(ui.abandon_button.get_global_rect()), "Actions remain inside page %s" % points)
		_check(ui.deliver_button.size.y >= 48 and ui.abandon_button.size.y >= 48, "Touch actions >=48 points %s" % points)
		await _capture("phone-" + str(points.x))
		ui.close()
	root.set_meta(&"touch_layout", false)
	root.set_meta(&"safe_insets", Vector4.ZERO)
	DisplayServer.window_set_size(Vector2i(500, 400))
	Language.set_language("en")
	await get_tree().create_timer(0.4).timeout
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.2).timeout
	_check(ui.is_open, "E opens board at desktop 500x400")
	_check(ui.panel.get_global_rect().encloses(ui.deliver_button.get_global_rect()), "Desktop window retains action buttons")
	await _capture("desktop-500")
	key = InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.1).timeout
	_check(not ui.is_open, "Escape closes order board")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = TimeManager.now()
	var snapshot: Dictionary = adapter.capture("orders_preview", 1, now)
	var folder: String = "res://.godot/orders-preview-" + Crypto.new().generate_random_bytes(6).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(folder, SaveCatalog.new())
	var written: Dictionary = await repository.write_profile_async("orders_preview", snapshot, 0)
	_check(written.ok, "Active order instances save to disk asynchronously")
	var read_back: Dictionary = repository.read_profile("orders_preview")
	_check(read_back.ok and read_back.has("snapshot"), "Saved active orders pass checksum and schema validation")
	if read_back.ok and read_back.has("snapshot"):
		_check(adapter.restore(read_back.snapshot, now + 3600).ok, "Disk save restores after offline time")
		_check(orders.capture() == snapshot.orders, "Disk roundtrip preserves IDs, cursor and completed count")
		_check(player.wallet.balance == int(snapshot.coins), "Disk reload does not re-credit delivery reward")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(repository.path("orders_preview") + suffix):
			DirAccess.remove_absolute(repository.path("orders_preview") + suffix)
	DirAccess.remove_absolute(folder)
	var report: Dictionary = {"checks": checks, "failures": failures}
	var file: FileAccess = FileAccess.open("res://../orders-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
