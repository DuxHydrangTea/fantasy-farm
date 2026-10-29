extends "res://tests/support/hotbar_skin_probe.gd"
func _click(button: BaseButton) -> void:
	# Keep a synthetic click together so physical pointer motion cannot cancel
	# its release while the native QA window is running in the background.
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames(5)

func _layout(menu: WorkerMenu, confirming: bool = false) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	_check(bounds.encloses(_screen_rect(menu.panel)), "Worker panel fits viewport")
	var actions: Array[Button] = []
	actions.assign([menu.confirm_button, menu.cancel_button] if confirming else [menu.hire_button, menu.dismiss_button, menu.pause_crop_button])
	actions.append(menu.close_button)
	for button: Button in actions:
		if not button.is_visible_in_tree():
			continue
		_check(bounds.encloses(_screen_rect(button)), "Worker action fits viewport")
		_check(button.size.y >= 48, "Worker action retains touch target")

func _open(role: String) -> WorkerMenu:
	var board: WorkerBoard = world.get_node({"crop":"CropWorkers","ranch":"RanchWorkers","orchard":"OrchardWorkers"}[role]) as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0,24)
	_check(board.open_shop(world.player), "Role board opens: " + role)
	await _frames(6)
	return board.menu as WorkerMenu

func _run() -> void:
	var fixture: Node2D = preload("res://tests/support/worker_layout_fixture.tscn").instantiate() as Node2D
	add_child(fixture)
	world = fixture.get("world") as FarmWorld
	var menu: WorkerMenu = fixture.get("menu") as WorkerMenu
	await _frames(12)
	_layout(menu)
	_check(menu.preview != (world.workers.actor_for("crop")).sprite and menu.preview.is_playing(), "Portrait animation is independent from actor")
	await _capture("crop-runtime-desktop-vi")
	await _click(menu.auto_fertilize_button)
	_check(not world.workers.crop_automation.auto_fertilize, "Mouse toggles fertilizer option")
	await _click(menu.auto_plant_button)
	_check(not world.workers.crop_automation.auto_plant, "Mouse toggles planting option")
	await _click(menu.pause_crop_button)
	_check(world.workers.crop_automation.paused and world.workers.record("crop").employed, "Pause preserves employment and wage responsibility")
	await _click(menu.dismiss_button)
	_check(menu.confirmation.visible, "Dismiss opens confirmation")
	_layout(menu, true)
	await _capture("dismissal-desktop-vi")
	await _click(menu.cancel_button)
	_check(world.workers.record("crop").employed, "Cancel keeps worker employed")
	Language.set_language("en")
	await _frames(4)
	await _capture("crop-runtime-desktop-en")
	for viewport_size: Vector2i in [Vector2i(844,390),Vector2i(667,375)]:
		Language.set_language("vi")
		get_viewport().set_meta("touch_ui_override",true)
		get_viewport().set_meta("safe_insets",Vector4(24,0,24,12))
		get_tree().root.size = viewport_size
		await _frames(15)
		_layout(menu)
		await _capture("crop-runtime-phone-"+str(viewport_size.x))
		await _touch_click(menu.dismiss_button)
		_layout(menu,true)
		await _capture("dismissal-phone-"+str(viewport_size.x))
		await _touch_click(menu.cancel_button)
	await _touch_click(menu.pause_crop_button)
	_check(not world.workers.crop_automation.paused, "Touch resumes crop work")
	await _touch_click(menu.dismiss_button)
	var balance: int = world.player.wallet.balance
	await _touch_click(menu.confirm_button)
	_check(not world.workers.record("crop").employed and world.player.wallet.balance == balance, "Confirmed dismissal does not charge coins")
	await _touch_click(menu.hire_button)
	_check(world.workers.record("crop").employed and world.player.wallet.balance == balance - int(WorkerRole.WAGES.crop), "Rehire charges today's wage once")
	menu.close(false)
	menu = await _open("ranch")
	_check(not menu.zones.disabled and (menu.get_node("%ZoneBox") as Control).visible, "Ranch allows selecting pen before hire")
	menu.zones.select(1)
	var zone: String = String(menu.zones.get_item_metadata(1))
	await _touch_click(menu.hire_button)
	_check(world.workers.record("ranch").zone == zone and menu.zones.disabled, "Hire locks the chosen pen")
	_layout(menu)
	await _capture("ranch-runtime-phone")
	menu.close(false)
	get_viewport().set_meta("touch_ui_override",false)
	get_viewport().set_meta("safe_insets",Vector4.ZERO)
	get_tree().root.size = Vector2i(1280,720)
	menu = await _open("orchard")
	_check(not (menu.get_node("%CropOptions") as Control).visible, "Orchard does not show crop toggles")
	await _click(menu.hire_button)
	_check(world.workers.record("orchard").employed, "Orchard hire works")
	_layout(menu)
	await _capture("orchard-runtime-desktop-vi")
	menu.close(false)
	_check(not world.player.selection.shop_open, "Closing releases modal")
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
