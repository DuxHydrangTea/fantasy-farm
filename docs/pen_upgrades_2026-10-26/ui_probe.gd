extends Node2D
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var failures: Array[String] = []
var checks: int = 0
var output: String = "res://docs/pen_upgrades_2026-10-26"

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _frames(count: int = 3) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func _open(index: int) -> PenDashboard:
	var board: PenBoard = world.pen_boards[index]
	world.player.global_position = board.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	_check(board.open_board(world.player), "Open board " + str(index))
	await _frames()
	return board.menu

func _capture(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output + "/" + name + ".png")

func _press(button: Button, touch: bool = false) -> void:
	var point: Vector2 = get_tree().root.get_stretch_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await _frames(2)
	for down: bool in [true, false]:
		if touch:
			var event: InputEventScreenTouch = InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = down
			get_viewport().push_input(event, true)
		else:
			var event: InputEventMouseButton = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.global_position = point
			event.pressed = down
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			get_viewport().push_input(event, true)
		await _frames(1)

func _run() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.gpu_grass_enabled = false
	add_child(world)
	await _frames(10)
	world.farming.time_manager.set_process(false)
	world.pen_upgrades.profile_ready = true
	Language.set_language("vi")
	world.player.wallet.set_balance(20000)
	var menu: PenDashboard = await _open(0)
	_check(not menu.upgrade_button.disabled, "Enough coins enables upgrade")
	await _capture("coop-before")
	await _press(menu.upgrade_button)
	_check(menu.board.pen.capacity == 10, "Mouse click opens five spaces")
	_check(world.player.wallet.balance == 0, "Charge exactly 20000")
	await _press(menu.upgrade_button)
	_check(menu.board.pen.capacity == 10 and world.player.wallet.balance == 0, "Double click does not spend again")
	await _capture("coop-after")
	menu.close()
	menu = await _open(1)
	_check(menu.upgrade_button.disabled, "Insufficient coins disable barn upgrade")
	await _capture("barn-insufficient")
	menu.close()
	world.player.wallet.set_balance(10000000)
	menu = await _open(2)
	await _press(menu.upgrade_button, true)
	_check(menu.board.pen.capacity == 10, "Touch opens pond spaces")
	menu.close()
	await _frames(2)
	for level: int in range(2, 6):
		_check(world.pen_upgrades.purchase(menu.board.pen, level, world.pen_upgrades.catalog.price(menu.board.pen.persistent_id, level)).ok, "Pond upgrade level " + str(level))
	get_tree().root.size = Vector2i(844, 390)
	await _frames(5)
	menu = await _open(2)
	_check(menu.upgrade_button.disabled and menu.board.pen.capacity == 30, "Maximum shows disabled button")
	_check(menu.panel.get_global_rect().encloses(menu.upgrade_button.get_global_rect()), "Mobile upgrade button fits panel")
	await _capture("pond-max-mobile")
	menu.close()
	get_tree().root.size = Vector2i(390, 844)
	await _frames(5)
	Language.set_language("en")
	menu = await _open(0)
	_check(menu.panel.get_global_rect().encloses(menu.upgrade_button.get_global_rect()), "Portrait upgrade button fits panel")
	await _capture("coop-portrait-en")
	menu.close()
	world.player.wallet.set_balance(100000000)
	for board: PenBoard in world.pen_boards:
		while world.pen_upgrades.state.level(board.pen.persistent_id) < 6:
			var current: int = world.pen_upgrades.state.level(board.pen.persistent_id)
			var result: Dictionary = world.pen_upgrades.purchase(board.pen, current, world.pen_upgrades.catalog.price(board.pen.persistent_id, current))
			_check(result.ok, "Prepare capacity for native placement check")
			if not result.ok:
				break
	await _frames(10)
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var trading: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, world.farming.time_manager)
	for offer: AnimalShopOffer in stock.animal_offers:
		_check(trading.quote_buy(offer, 30).ok, "30 arrival positions with live map physics: " + str(offer.animal.animal_id))
	var file: FileAccess = FileAccess.open(output + "/ui-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}, "\t"))
	file.close()
	world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
