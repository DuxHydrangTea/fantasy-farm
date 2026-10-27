extends "res://tests/support/hotbar_skin_probe.gd"
var fixture: ManagementRedesignFixture

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

func _menu_layout(menu: TradeMenu, panel: Control, action: Button) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	_check(bounds.encloses(_screen_rect(panel)), "Management panel stays within viewport")
	_check(bounds.encloses(_screen_rect(menu.close_button)), "Close stays within viewport")
	_check(bounds.encloses(_screen_rect(action)), "Upgrade action stays within viewport")
	_check(action.size.y >= 48 and menu.close_button.size.y >= 48, "Actions retain touch target sizes")

func _run() -> void:
	fixture = preload("res://tests/support/management_redesign_fixture.tscn").instantiate() as ManagementRedesignFixture
	add_child(fixture)
	world = fixture.world
	await _frames(10)
	var pen: PenDashboard = world.get_node("CoopPen/ManagementSign/PenMenu") as PenDashboard
	_menu_layout(pen, pen.panel, pen.upgrade_button)
	_check(pen.cards.size() == 4, "Only this pen's four animals are shown")
	for card: AnimalCard in pen.cards.values():
		_check(card.preview != card.animal.sprite and card.preview.is_playing(), "Portrait animation is independent")
	await _capture("pen-runtime-desktop-vi")
	var price: int = int(pen._upgrade_offer.price)
	var capacity: int = pen.board.pen.capacity
	var wallet: int = world.player.wallet.balance
	await _click(pen.upgrade_button)
	_check(pen.board.pen.capacity == capacity + 5 and world.player.wallet.balance == wallet - price, "Mouse upgrade adds five spaces at actual catalog price")
	pen._purchase_upgrade()
	_check(world.player.wallet.balance == wallet - price, "Cooldown prevents duplicate upgrade")
	Language.set_language("en")
	await _frames(4)
	_check(pen.heading.text == PenStatus.title(pen.board.pen), "Pen title translates live")
	await _capture("pen-runtime-desktop-en")
	Language.set_language("vi")
	get_viewport().set_meta("touch_ui_override", true)
	get_viewport().set_meta("safe_insets", Vector4(44, 0, 44, 21))
	get_tree().root.size = Vector2i(844, 390)
	await _frames(12)
	_menu_layout(pen, pen.panel, pen.upgrade_button)
	_check(pen.grid.columns >= 2 and pen.scroll.size.y > 48, "Phone roster keeps two columns and a scrollable area")
	await _capture("pen-runtime-phone")
	await _touch_click(pen.close_button)
	_check(not world.player.selection.shop_open, "Touch close releases modal lock")
	var tree: TreePlotMenu = fixture.open_tree()
	await _frames(8)
	_menu_layout(tree, tree.panel, tree.upgrade_button)
	_check(tree.plot_preview.capacity == 27 and (tree.get_node("%PlantedValue") as Label).text == "18", "Plot summary uses actual capacity and tree count")
	await _capture("tree-runtime-phone")
	world.player.wallet.set_balance(1000000)
	tree.refresh()
	wallet = world.player.wallet.balance
	price = int(tree._offer.price)
	await _touch_click(tree.upgrade_button)
	_check(tree.plot_preview.capacity == 36 and world.player.wallet.balance == wallet - price, "Touch unlocks nine plots at actual catalog price")
	tree._purchase()
	_check(world.player.wallet.balance == wallet - price, "Tree upgrade cooldown prevents duplicate charge")
	get_viewport().set_meta("touch_ui_override", false)
	get_viewport().set_meta("safe_insets", Vector4.ZERO)
	get_tree().root.size = Vector2i(1280, 720)
	await _frames(45)
	_menu_layout(tree, tree.panel, tree.upgrade_button)
	await _capture("tree-runtime-desktop-vi")
	Language.set_language("en")
	await _frames(4)
	await _capture("tree-runtime-desktop-en")
	Language.set_language("vi")
	get_viewport().set_meta("touch_ui_override", true)
	get_tree().root.size = Vector2i(667, 375)
	await _frames(10)
	_menu_layout(tree, tree.panel, tree.upgrade_button)
	await _capture("tree-runtime-small-phone")
	tree.close(false)
	pen = fixture.open_pen()
	await _frames(6)
	_menu_layout(pen, pen.panel, pen.upgrade_button)
	await _capture("pen-runtime-small-phone")
	world.player.wallet.set_balance(0)
	pen.refresh()
	_check(pen.upgrade_button.disabled, "Insufficient coins disables pen upgrade")
	pen.close(false)
	_check(not world.player.selection.shop_open, "Final close releases input")
	for board: PenBoard in world.pen_boards:
		if board.pen == pen.board.pen:
			continue
		world.player.global_position = board.global_position + Vector2(0, 24)
		_check(board.open_board(world.player), "Other pen board opens: " + board.pen.name)
		await _frames(4)
		_menu_layout(board.menu, board.menu.panel, board.menu.upgrade_button)
		_check(board.menu.empty.visible, "Empty pen has a clear empty state")
		board.menu.close(false)
	var timber: TreePlotBoard = world.get_node("TimberPlotBoard") as TreePlotBoard
	world.player.global_position = timber.global_position + Vector2(0, 24)
	_check(timber.open_board(world.player), "Timber plot board opens")
	await _frames(4)
	_menu_layout(timber.menu, timber.menu.panel, timber.menu.upgrade_button)
	_check(timber.menu.plot_preview.kind == TreeDefinition.Kind.TIMBER and timber.menu.plot_preview.capacity == 9, "Timber map uses its own progress")
	timber.menu.close(false)
	var report: Dictionary = {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
