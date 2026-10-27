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

func _run() -> void:
	var fixture: Node2D = preload("res://tests/support/cooking_layout_fixture.tscn").instantiate() as Node2D
	add_child(fixture)
	world = fixture.get("world") as FarmWorld
	var menu: CookingMenu = fixture.get("menu") as CookingMenu
	await _frames(12)
	_check(menu.is_open, "Chef opens the scene-authored kitchen")
	_check(menu.recipe_buttons.size() == ChefCooking.RECIPES.size(), "All shipped recipes are listed")
	_check(world.cooking.ready.size() == 1 and world.cooking.queue.size() == 2, "Fixture shows real queued and ready dishes")
	await _capture("runtime-desktop-vi")
	await _click(menu.collect_button)
	_check(world.player.selection.inventory.count_item(&"fried_egg") == 1, "Mouse collects completed dish")
	await _click(menu.get_node("%Maximum") as Button)
	_check(int(menu.quantity.value) == 9, "Mouse maximum uses actual ingredients")
	await _click(menu.cook_button)
	_check(world.cooking.queue.size() == 11, "Mouse cook queues selected batch")
	_check(world.player.selection.inventory.count_item(&"chicken_egg") == 0, "Queued ingredients are consumed exactly once")
	await _click(menu.get_node("%CookableRecipes") as Button)
	_check((menu.get_node("%EmptyRecipes") as Label).visible, "Cookable filter shows empty state after using ingredients")
	await _click(menu.get_node("%AllRecipes") as Button)
	menu.browse.ensure_control_visible(menu.recipe_buttons.back())
	await _frames(5)
	await _click(menu.recipe_buttons.back())
	_check(menu.selected == ChefCooking.RECIPES.back(), "Last recipe can be scrolled to and selected")
	menu._select(ChefCooking.RECIPES[0])
	menu.browse.scroll_vertical = 0
	Language.set_language("en")
	await _frames(4)
	await _capture("runtime-desktop-en")
	for viewport_size: Vector2i in [Vector2i(844,390), Vector2i(667,375)]:
		Language.set_language("vi")
		get_viewport().set_meta("touch_ui_override", true)
		get_viewport().set_meta("safe_insets", Vector4(24, 0, 24, 12))
		get_tree().root.size = viewport_size
		await _frames(15)
		var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
		for control: Control in [menu.panel,menu.close_button,menu.cook_button,menu.collect_button]:
			_check(bounds.encloses(_screen_rect(control)), "Panel/action fits " + str(viewport_size))
		_check(menu.cook_button.size.y >= 48, "Cook has a touch-sized target")
		await _capture("runtime-phone-" + str(viewport_size.x))
	var quantity_controls: TouchQuantityComponent
	for child: Node in menu.quantity.get_children():
		if child is TouchQuantityComponent:
			quantity_controls = child as TouchQuantityComponent
	(menu.get_node("%ActionScroll") as ScrollContainer).ensure_control_visible(menu.quantity)
	await _frames(5)
	await _touch_click(quantity_controls.increase)
	_check(int(menu.quantity.value) == 2, "Touch plus changes batch size")
	await _touch_click(quantity_controls.decrease)
	_check(int(menu.quantity.value) == 1, "Touch minus restores batch size")
	await _touch_click(menu.close_button)
	_check(not world.player.selection.shop_open, "Touch close releases modal")
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
