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

func _layout(menu: ProduceSalesUI) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	for control: Control in [menu.panel, menu.close_button, menu.quantity, menu.sell_quantity_button, menu.sell_all_button]:
		_check(bounds.encloses(_screen_rect(control)), "Sales panel/control stays inside screen")
	_check(menu.sell_quantity_button.size.y >= 48 and menu.sell_all_button.size.y >= 48, "Both sale actions retain touch size")

func _run() -> void:
	var fixture: Node2D = preload("res://tests/support/produce_sales_fixture.tscn").instantiate() as Node2D
	add_child(fixture)
	world = fixture.get("world") as FarmWorld
	var menu: ProduceSalesUI = fixture.get("menu") as ProduceSalesUI
	await _frames(12)
	_layout(menu)
	await _capture("runtime-desktop-vi")
	var carrot: ProducePrice = menu.selected
	var balance: int = world.player.wallet.balance
	await _click(menu.sell_quantity_button)
	_check(world.player.wallet.balance == balance + carrot.price * 10, "Mouse sells entered amount at live price")
	_check(world.player.selection.inventory.count_item(carrot.item.item_id, 0) == 14, "Only normal items are sold")
	await _click(menu.quality_tabs[1])
	_check(menu.service.tier == 1 and menu.service.quantity(menu.selected) == 5, "Mouse selects Silver tab")
	await _click(menu.get_node("%Maximum") as Button)
	_check(int(menu.quantity.value) == 5, "Maximum selects entire owned Silver stack")
	Language.set_language("en")
	await _frames(5)
	await _capture("runtime-desktop-en")
	for viewport_size: Vector2i in [Vector2i(844,390),Vector2i(667,375)]:
		Language.set_language("vi")
		get_viewport().set_meta("touch_ui_override", true)
		get_viewport().set_meta("safe_insets", Vector4(24,0,24,12))
		get_tree().root.size = viewport_size
		await _frames(15)
		_layout(menu)
		await _capture("runtime-phone-"+str(viewport_size.x))
	await _touch_click(menu.quality_tabs[2])
	_check(menu.service.tier == 2, "Touch selects Gold tab")
	var controls: TouchQuantityComponent
	for child: Node in menu.quantity.get_children():
		if child is TouchQuantityComponent:
			controls = child as TouchQuantityComponent
	await _touch_click(controls.increase)
	_check(int(menu.quantity.value) == 2, "Touch plus changes quantity")
	balance = world.player.wallet.balance
	await _touch_click(menu.sell_quantity_button)
	_check(world.player.wallet.balance == balance + ItemQuality.unit_price(carrot.price, 2) * 2, "Touch sells Gold at quality price")
	_check((menu.get_node("%Empty") as Label).visible, "Empty quality has an explicit empty state")
	await _touch_click(menu.quality_tabs[0])
	_check(menu.row_buttons.size() == 4, "Normal items reappear after switching quality")
	balance = world.player.wallet.balance
	var quoted: Dictionary = menu.service.quote_all()
	await _touch_click(menu.sell_all_button)
	_check(world.player.wallet.balance == balance + int(quoted.total), "Bulk touch sale matches all-type quote")
	_check(world.player.selection.inventory.count_item(carrot.item.item_id, 1) == 5, "Bulk sale preserves Silver stock")
	await _touch_click(menu.close_button)
	_check(not world.player.selection.shop_open, "Touch close releases modal")
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
