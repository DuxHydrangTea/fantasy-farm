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

func _layout(menu: OrderUI, confirming: bool = false) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	_check(bounds.encloses(_screen_rect(menu.panel)), "Order panel stays inside safe viewport")
	var actions: Array[Button] = []
	actions.assign([menu.confirm_button, menu.cancel_button] if confirming else [menu.deliver_button, menu.perfect_button, menu.abandon_button, menu.refill_button, menu.rows[0]])
	actions.append(menu.close_button)
	for button: Button in actions:
		_check(bounds.encloses(_screen_rect(button)), "Order action stays visible")
		_check(button.size.y >= 48, "Order action retains touch target")

func _run() -> void:
	var fixture: Node2D = preload("res://tests/support/order_layout_fixture.tscn").instantiate() as Node2D
	add_child(fixture)
	world = fixture.get("world") as FarmWorld
	var menu: OrderUI = fixture.get("menu") as OrderUI
	await _frames(12)
	_layout(menu)
	_check(menu.rows.size() == 3, "Exactly three slots are shown")
	await _capture("runtime-desktop-vi")
	var before: Dictionary = world.orders.service.capture()
	await _click(menu.deliver_button)
	_check(menu.confirmation.visible, "Normal delivery opens confirmation")
	_layout(menu, true)
	await _capture("confirmation-normal-desktop-vi")
	await _click(menu.cancel_button)
	_check(world.orders.service.capture() == before, "Cancel preserves order state")
	await _click(menu.perfect_button)
	var plan: Dictionary = menu._pending_plan.duplicate(true)
	_check(plan.ok and not menu.confirm_button.disabled, "Perfect confirmation uses a valid exact-tier plan")
	await _capture("confirmation-perfect-desktop-vi")
	var balance: int = world.player.wallet.balance
	await _click(menu.confirm_button)
	_check(world.player.wallet.balance == balance + int(plan.coins), "Mouse confirms perfect delivery at quoted reward")
	_check(int(world.orders.service.capture().completed) == int(before.completed) + 1, "Delivery completes one order")
	menu._confirm()
	_check(world.player.wallet.balance == balance + int(plan.coins), "Repeated confirmation cannot pay twice")
	Language.set_language("en")
	await _frames(5)
	await _capture("runtime-desktop-en")
	for viewport_size: Vector2i in [Vector2i(844,390), Vector2i(667,375)]:
		Language.set_language("vi")
		get_viewport().set_meta("touch_ui_override", true)
		get_viewport().set_meta("safe_insets", Vector4(24,0,24,12))
		get_tree().root.size = viewport_size
		await _frames(15)
		_layout(menu)
		await _capture("runtime-phone-" + str(viewport_size.x))
		await _touch_click(menu.abandon_button)
		_check(menu.confirmation.visible, "Touch abandon opens confirmation")
		_layout(menu, true)
		await _capture("confirmation-phone-" + str(viewport_size.x))
		await _touch_click(menu.cancel_button)
		_check(not menu.confirmation.visible, "Touch cancel returns to board")
	await _touch_click(menu.rows[1])
	_check(menu._selected_index == 1, "Touch selects another order card")
	await _touch_click(menu.abandon_button)
	balance = world.player.wallet.balance
	await _touch_click(menu.confirm_button)
	_check(world.player.wallet.balance == balance, "Abandon has no coin penalty")
	await _touch_click(menu.close_button)
	_check(not world.player.selection.shop_open, "Touch close releases modal")
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
