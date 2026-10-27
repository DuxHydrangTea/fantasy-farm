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

func _layout(menu: GraftMenu) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	_check(bounds.encloses(_screen_rect(menu.panel)), "Graft panel fits viewport")
	for button: Button in [menu.harvest_button,menu.confirm_button,menu.close_button]:
		_check(bounds.encloses(_screen_rect(button)), "Pinned graft action fits viewport")
		_check(button.size.y >= 48, "Graft action retains touch size")

func _run() -> void:
	var fixture: Node2D = preload("res://tests/support/graft_layout_fixture.tscn").instantiate() as Node2D
	add_child(fixture)
	world = fixture.get("world") as FarmWorld
	var tree: FruitTree = fixture.get("tree") as FruitTree
	var menu: GraftMenu = world.graft_menu
	var bag: InventoryComponent = world.player.selection.inventory
	await _frames(12)
	_layout(menu)
	_check(tree.pending_graft == FruitTree.Graft.NONE, "Reviewing does not apply or spend")
	await _capture("runtime-desktop-free-vi")
	await _click(menu.confirm_button)
	_check(tree.pending_graft == FruitTree.Graft.YIELD and tree.active_graft == FruitTree.Graft.NONE, "Mouse confirms first free graft")
	_check(bag.count_item(GraftService.WAX) == 2, "Free choice preserves wax")
	await _click(menu.harvest_button)
	_check(bag.count_item(&"apple") == 300 and tree.active_graft == FruitTree.Graft.YIELD, "Harvest preserves old batch and activates next strategy")
	tree.fruit_work = tree.definition.fruit_cycle_seconds * 0.35
	tree.update_visual()
	menu.browse.ensure_control_visible(menu.quality_button)
	await _frames(4)
	await _click(menu.quality_button)
	_check(tree.pending_graft == FruitTree.Graft.NONE, "Paid review does not mutate tree")
	await _capture("runtime-desktop-paid-vi")
	await _click(menu.confirm_button)
	_check(tree.pending_graft == FruitTree.Graft.QUALITY and bag.count_item(GraftService.WAX) == 1, "Mouse switch consumes exactly one wax")
	_check(tree.harvest_amount() == 600 and tree.harvest_item() == tree.definition.harvest_item, "Current growing Yield batch stays unchanged")
	menu._confirm_choice()
	_check(bag.count_item(GraftService.WAX) == 1, "Duplicate confirmation cannot spend again")
	Language.set_language("en")
	await _frames(4)
	await _capture("runtime-desktop-en")
	menu._select_direction(FruitTree.Graft.YIELD)
	for viewport_size: Vector2i in [Vector2i(844,390),Vector2i(667,375)]:
		Language.set_language("vi")
		get_viewport().set_meta("touch_ui_override",true)
		get_viewport().set_meta("safe_insets",Vector4(24,0,24,12))
		get_tree().root.size = viewport_size
		await _frames(15)
		_layout(menu)
		menu._show_review()
		await _frames(4)
		await _capture("runtime-phone-"+str(viewport_size.x))
	tree.fruit_work = tree.definition.fruit_cycle_seconds
	tree.update_visual()
	menu._refresh()
	await _frames(3)
	await _touch_click(menu.harvest_button)
	_check(bag.count_item(&"apple") == 900 and tree.active_graft == FruitTree.Graft.QUALITY, "Touch harvest collects old 600 and activates Star fruit")
	_check(tree.harvest_item() == tree.definition.star_harvest_item and tree.harvest_amount() == 300, "New Star batch uses base amount")
	menu.browse.ensure_control_visible(menu.yield_button)
	await _frames(5)
	await _touch_click(menu.yield_button)
	_check(not menu.confirm_button.disabled and bag.count_item(GraftService.WAX) == 1, "Touch reviews without spending wax")
	await _touch_click(menu.confirm_button)
	_check(tree.pending_graft == FruitTree.Graft.YIELD and bag.count_item(GraftService.WAX) == 0, "Touch confirms next switch once")
	_check(tree.harvest_item() == tree.definition.star_harvest_item, "Current Star batch remains Star after scheduling")
	await _touch_click(menu.close_button)
	_check(not world.player.selection.shop_open, "Touch close releases modal")
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
