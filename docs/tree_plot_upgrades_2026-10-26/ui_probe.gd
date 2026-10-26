extends Node2D
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var failures: Array[String] = []
var checks: int = 0
var output: String = "res://docs/tree_plot_upgrades_2026-10-26"

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

func _open(kind: TreeDefinition.Kind) -> TreePlotMenu:
	var board: TreePlotBoard = world.get_node("FruitPlotBoard" if kind == TreeDefinition.Kind.FRUIT else "TimberPlotBoard") as TreePlotBoard
	world.player.global_position = board.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	await _frames(3)
	var target: InteractionTarget = world.player.interactions.resolver.resolve()
	_check(target != null and target.node == board, "Keyboard resolver finds tree board")
	_check(world.player.interactions.resolver.clicked(board.sprite.global_position).node == board, "Click resolver finds tree board")
	_check(target != null and world.player.interactions.execute(target), "Execute tree board interaction")
	await _frames()
	return board.menu

func _run() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.gpu_grass_enabled = false
	add_child(world)
	await _frames(10)
	world.farming.time_manager.set_process(false)
	world.tree_plot_upgrades.profile_ready = true
	Language.set_language("vi")
	world.player.wallet.set_balance(30000)
	var menu: TreePlotMenu = await _open(TreeDefinition.Kind.FRUIT)
	_check(not menu.upgrade_button.disabled, "Enough coins enable upgrade")
	await _capture("fruit-before")
	await _press(menu.upgrade_button)
	_check(world.tree_plot_upgrades.state.capacity(TreeDefinition.Kind.FRUIT) == 18, "Mouse unlocks nine plots")
	_check(world.player.wallet.balance == 0, "Charge exactly 30000")
	await _press(menu.upgrade_button)
	_check(world.player.wallet.balance == 0, "Double click cannot spend twice")
	await _capture("fruit-after")
	menu.close()
	menu = await _open(TreeDefinition.Kind.TIMBER)
	_check(menu.upgrade_button.disabled, "Insufficient coins disables purchase")
	await _capture("timber-insufficient")
	menu.close()
	world.player.wallet.set_balance(100000000)
	menu = await _open(TreeDefinition.Kind.TIMBER)
	await _press(menu.upgrade_button, true)
	_check(world.tree_plot_upgrades.state.capacity(TreeDefinition.Kind.TIMBER) == 18, "Touch unlocks nine timber plots")
	menu.close()
	get_tree().root.size = Vector2i(844,390)
	await _frames(5)
	menu = await _open(TreeDefinition.Kind.FRUIT)
	_check(menu.panel.get_global_rect().encloses(menu.upgrade_button.get_global_rect()), "Landscape mobile upgrade fits")
	await _capture("fruit-mobile")
	menu.close()
	get_tree().root.size = Vector2i(390,844)
	await _frames(5)
	menu = await _open(TreeDefinition.Kind.TIMBER)
	_check(menu.panel.get_global_rect().encloses(menu.upgrade_button.get_global_rect()), "Portrait mobile upgrade fits")
	await _capture("timber-portrait")
	menu.close()
	world.tree_plot_upgrades.restore({"fruit":17,"timber":17})
	get_tree().root.size = Vector2i(1280,720)
	await _frames(5)
	menu = await _open(TreeDefinition.Kind.FRUIT)
	_check(menu.upgrade_button.disabled, "Maximum capacity disables purchase")
	await _capture("fruit-max")
	menu.close()
	world.tree_plot_upgrades.restore(TreePlotUpgradeState.fresh())
	world.player.global_position = world.trees.point_for(Vector2i(27,76))
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.reset_smoothing()
	await _capture("locked-plots")
	var file: FileAccess = FileAccess.open(output + "/ui-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	get_tree().quit(0 if failures.is_empty() else 1)
