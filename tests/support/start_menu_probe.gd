extends Node
## End-to-end startup/profile QA with its own save directory, never personal data.
var failures: Array[String] = []
var checks: int = 0
var output: String
var first: String
var second: String

func _ready() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	SaveManager.local_directory = "user://startup_probe_" + Crypto.new().generate_random_bytes(6).hex_encode()
	Engine.max_fps = 60
	_run.call_deferred()

func _frames(count: int = 5) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures.append(title)
		push_error(title)

func _click(button: Button) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames()

func _capture(title: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(title + ".png"))

func _wait_farm() -> bool:
	var until: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < until:
		if SaveManager.adapter != null and SaveManager.writes_enabled and not SaveManager.busy and SaveManager.revision > 0:
			return true
		await get_tree().process_frame
	_check(false, "Farm finishes loading and commits its first save")
	return false

func _menu() -> Control:
	if SaveManager.adapter != null:
		var saved: Dictionary = await SaveManager.save_game()
		_check(saved.ok, "Save before leaving farm")
	get_tree().change_scene_to_file("res://world/start_menu.tscn")
	await _frames(15)
	return get_tree().current_scene as Control

func _layout(menu: Control) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	_check(bounds.encloses((menu.get_node("%Card") as Control).get_global_rect()), "Start card fits window")
	for control: Control in menu.find_children("*", "Button", true, false):
		if control.is_visible_in_tree():
			_check(bounds.encloses(control.get_global_rect()), "Action fits: " + control.name)

func _run() -> void:
	# Keep this controller alive while only the selected scene is replaced.
	get_tree().current_scene = null
	var menu: Control = await _menu()
	_check((menu.get_node("%Continue") as Button).disabled, "Continue disabled on first launch")
	_layout(menu)
	await _capture("start-empty-vi")
	await _click(menu.get_node("%NewGame") as Button)
	(menu.get_node("%FarmName") as LineEdit).text = "Vườn Bình Minh"
	await _capture("new-farm-vi")
	await _click(menu.get_node("%Create") as Button)
	if not await _wait_farm():
		_finish()
		return
	first = SaveManager.profile_id
	_check(first != "local", "New farm has its own profile ID")
	_check(SaveManager.revision >= 1, "New game saved immediately")
	SaveManager.adapter.world.player.wallet.set_balance(43210)
	menu = await _menu()
	await _click(menu.get_node("%NewGame") as Button)
	(menu.get_node("%FarmName") as LineEdit).text = "Vườn Sau Nhà"
	await _click(menu.get_node("%Create") as Button)
	if not await _wait_farm():
		_finish()
		return
	second = SaveManager.profile_id
	_check(second != first, "Second farm has a different save ID")
	_check(SaveManager.adapter.world.player.wallet.balance != 43210, "Second farm starts independently")
	SaveManager.adapter.world.player.wallet.set_balance(54321)
	menu = await _menu()
	await _capture("start-continue-vi")
	await _click(menu.get_node("%Continue") as Button)
	if not await _wait_farm():
		_finish()
		return
	_check(SaveManager.profile_id == second, "Continue opens the most recent farm")
	_check(SaveManager.adapter.world.player.wallet.balance == 54321, "Continue restores its own money")
	menu = await _menu()
	await _click(menu.get_node("%SavedGames") as Button)
	_check((menu.get_node("%SavesList") as VBoxContainer).get_child_count() == 2, "Saved-farm list contains both farms")
	_layout(menu)
	await _capture("saved-farms-vi")
	for size: Vector2i in [Vector2i(667, 375), Vector2i(480, 640)]:
		get_tree().root.size = size
		await _frames(12)
		for page: String in ["_main", "_new_game", "_saved_games"]:
			menu.call(page)
			await _frames(8)
			_layout(menu)
			await _capture("menu-" + page + "-" + str(size.x))
	get_tree().root.size = Vector2i(1280, 720)
	Language.set_language("en")
	await _frames(12)
	await _capture("start-en")
	menu.call("_saved_games")
	await _frames()
	for button: Button in (menu.get_node("%SavesList") as VBoxContainer).get_children():
		if String(button.get_meta("profile_id")) == first:
			await _click(button)
			break
	if await _wait_farm():
		_check(SaveManager.profile_id == first, "Selecting an older farm opens the correct profile")
		_check(SaveManager.adapter.world.player.wallet.balance == 43210, "Older farm retained its money")
	menu = await _menu()
	await _frames(10)
	_finish()

func _finish() -> void:
	var file: FileAccess = FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "first": first, "second": second}, "  "))
	file.close()
	print("START_MENU_NATIVE ", JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
