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
	root.get_texture().get_image().save_png("res://../help-" + label + ".png")

func _claim_goal() -> void:
	await _tap(world.objective_ui.hud_button)
	await _tap(world.objective_ui.claim_button)
	await _tap(world.objective_ui.close_button)

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.weather.set_debug_hour(12)
	await get_tree().create_timer(0.5).timeout
	var ui: HelpUI = world.help_ui
	var player: FarmPlayer = world.player
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	await _capture("hint-en")
	await _tap(world.objective_ui.help_button)
	_check(ui.is_open, "Native ? opens Help")
	_check(ui.content.text.contains("Tap a hotbar"), "Help selects touch instructions")
	await _capture("current-en")
	await _tap(ui.topics[1])
	_check(ui.content.text.contains("joystick"), "Touch controls explain joystick")
	var current: int = ui.selected_topic
	var start: Vector2 = _physical(ui.topics[1])
	await _touch(0, start, true)
	for step: int in range(1, 9):
		await _drag(0, start - Vector2(0, step * 16))
	await _touch(0, start - Vector2(0, 128), false)
	_check(ui.selected_topic == current, "Topic swipe does not activate another topic")
	await _tap(ui.topics[3])
	var content_start: Vector2 = _physical(ui.content_scroll)
	await _touch(0, content_start, true)
	for step: int in range(1, 9):
		await _drag(0, content_start - Vector2(0, step * 12))
	await _touch(0, content_start - Vector2(0, 96), false)
	_check(ui.content_scroll.scroll_vertical > 0, "Native swipe scrolls offline/animal instructions")
	await _tap(ui.topics[5])
	_check(ui.support_button.visible and ui.support_button.disabled, "Normal starting supplies do not allow emergency seed")
	Language.set_language("vi")
	await _capture("recovery-vi")
	var goal_before: Dictionary = world.objectives.progress.capture()
	await _tap(ui.skip_button)
	_check(world.tutorial.capture().skipped, "Native skip disables hints")
	_check(world.objectives.progress.capture() == goal_before and player.wallet.balance == 1000, "Skipping does not complete objectives or grant rewards")
	await _tap(ui.toggle_button)
	_check(world.tutorial.capture().enabled and world.tutorial.seen("first_soil"), "Enable retains seen hints")
	await _tap(ui.close_button)
	_check(not player.selection.is_menu_open(), "Closing Help releases shared modal")
	_check(not player.state.navigation.has_focus, "Closing Help does not navigate")
	for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
		DisplayServer.window_set_size(points)
		await get_tree().create_timer(0.3).timeout
		await _tap(world.objective_ui.help_button)
		ui.topics[5].pressed.emit()
		await get_tree().create_timer(0.15).timeout
		_check(ui.panel.size.y <= ui.root.size.y and ui.panel.size.x <= ui.root.size.x, "Help fits safe area %s" % points)
		_check(ui.panel.get_global_rect().encloses(ui.support_button.get_global_rect()), "Recovery button stays within page %s" % points)
		_check(ui.toggle_button.size.y >= 48 and ui.skip_button.size.y >= 48, "Touch targets >=48 %s" % points)
		await _capture("phone-" + str(points.x))
		await _tap(ui.close_button)
	Language.set_language("en")
	DisplayServer.window_set_size(Vector2i(844, 390))
	await get_tree().create_timer(0.3).timeout
	# Follow the real introductory loop using native controls and animation impacts.
	var cell: Vector2i = Vector2i(56, 20)
	player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell + Vector2i.UP))
	player.animation.face(Vector2.DOWN)
	await _tap(hotbar.buttons[0])
	await _tap(player.mobile_controls.tool_button)
	await get_tree().create_timer(0.7).timeout
	_check(world.objectives.progress.ready_to_claim(), "Native hoe use completes first soil step")
	await _claim_goal()
	await _tap(hotbar.buttons[2])
	await _tap(player.mobile_controls.tool_button)
	await get_tree().create_timer(0.7).timeout
	_check(world.farming.get_crop(cell) != null and world.objectives.progress.ready_to_claim(), "Native seed use plants and completes step")
	await _claim_goal()
	await _tap(hotbar.buttons[1])
	await _tap(player.mobile_controls.tool_button)
	await get_tree().create_timer(0.7).timeout
	_check(world.objectives.progress.ready_to_claim(), "Native watering completes step")
	await _claim_goal()
	await get_tree().create_timer(10.2).timeout
	await _tap(player.mobile_controls.interact_button)
	await get_tree().create_timer(0.7).timeout
	_check(player.selection.inventory.count_item(&"carrot_produces") == 100 and world.objectives.progress.ready_to_claim(), "Native harvest follows real maturity and collects produce")
	await _claim_goal()
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	player.global_position = buyer.interaction_position() + Vector2(0, 24)
	player.animation.face(Vector2.UP)
	await get_tree().create_timer(0.2).timeout
	await _tap(player.mobile_controls.interact_button)
	var sales: ProduceSalesUI = buyer.menu as ProduceSalesUI
	_check(sales.is_open, "Native interaction reaches the correct produce buyer")
	await _tap(sales.sell_quantity_button)
	_check(player.selection.inventory.count_item(&"carrot_produces") == 99 and world.objectives.progress.ready_to_claim(), "Native sale finishes grow-harvest-sell loop")
	await _tap(sales.close_button)
	await _capture("first-sale")
	root.set_meta(&"touch_layout", false)
	root.set_meta(&"safe_insets", Vector4.ZERO)
	DisplayServer.window_set_size(Vector2i(500, 400))
	await get_tree().create_timer(0.3).timeout
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_H
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.2).timeout
	_check(ui.is_open, "H opens help in desktop 500x400")
	ui.topics[1].pressed.emit()
	_check(ui.content.text.contains("WASD"), "Desktop help uses keyboard/mouse instructions")
	await _capture("desktop-500")
	key = InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.1).timeout
	_check(not ui.is_open, "Escape closes Help")
	# Exercise the one-time safety net only after removing QA-only run supplies.
	for slot: int in range(player.selection.inventory.slot_count):
		var item: ItemDefinition = player.selection.inventory.get_slot_item(slot)
		if item != null and item.item_type in [ItemDefinition.ItemType.SEED, ItemDefinition.ItemType.PRODUCE]:
			player.selection.inventory.remove(item.item_id, player.selection.inventory.count_item(item.item_id))
	player.wallet.set_balance(0)
	ui.open_help()
	ui.topics[5].pressed.emit()
	await get_tree().create_timer(0.1).timeout
	await _tap(ui.support_button)
	_check(world.tutorial.capture().support_used and player.selection.inventory.count_item(&"carrot_seed") == 1, "Native rescue grants exactly one seed when eligible")
	await _tap(ui.support_button)
	_check(player.selection.inventory.count_item(&"carrot_seed") == 1 and player.wallet.balance == 0, "Repeated rescue grants no extra seed or coins")
	await _tap(ui.skip_button)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = TimeManager.now()
	var snapshot: Dictionary = adapter.capture("help_preview", 1, now)
	var folder: String = "res://.godot/help-preview-" + Crypto.new().generate_random_bytes(6).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(folder, SaveCatalog.new())
	var written: Dictionary = await repository.write_profile_async("help_preview", snapshot, 0)
	_check(written.ok, "Seen hints and support flag save asynchronously")
	var read_back: Dictionary = repository.read_profile("help_preview")
	_check(read_back.ok and read_back.has("snapshot"), "Tutorial disk save passes checksum and schema")
	if read_back.ok and read_back.has("snapshot"):
		_check(adapter.restore(read_back.snapshot, now + 3600).ok, "Tutorial disk save restores after offline time")
		_check(world.tutorial.capture() == snapshot.tutorial, "Seen, skip and rescue state survive disk reload")
		_check(not ui.is_open and not ui.support.claim().ok, "Load closes Help and cannot grant rescue twice")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(repository.path("help_preview") + suffix):
			DirAccess.remove_absolute(repository.path("help_preview") + suffix)
	DirAccess.remove_absolute(folder)
	var report: Dictionary = {"checks": checks, "failures": failures}
	var file: FileAccess = FileAccess.open("res://../help-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
