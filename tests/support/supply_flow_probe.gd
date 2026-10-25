extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const FEED: ItemDefinition = preload("res://items/feeds/poultry_feed.tres")
var world: FarmWorld
var _checks: int = 0
var _failures: Array[String] = []
var _output: String

func _ready() -> void:
	_output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_output)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)

func _frames(count: int = 3) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func _capture(name: String) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size - Vector2(2, 2)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output + "/" + name + ".png")

func _click(button: Button) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames()

func _touch(id: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _run() -> void:
	Language.set_language("vi")
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(1000000)
	world.land.state.restore_columns(48, 4)
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	var stock: ShopCatalog = preload("res://resources/shops/farm_supply.tres")
	var trades: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, world.farming.time_manager)
	var bought: Dictionary = trades.buy(stock.animal_offers[0], 1)
	_check(bought.ok, "Buying an actual animal works with shared storage world")
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(SEED, 12)
	var access: FarmStorageAccess = world.storage_accesses.farm_supply_storage
	world.player.global_position = access.global_position + Vector2(0, 24)
	await _frames(8)
	_check(access.open_shop(world.player), "Supply building opens")
	await _frames(5)
	var store_menu: FarmStorageMenu = access.menu as FarmStorageMenu
	await _click(store_menu.find_child("DepositAll", true, false) as Button)
	_check(bag.count_item(SEED.item_id) == 0 and bag.count_item(FEED.item_id) == 0, "GUI deposits all seeds and feed")
	var supplies: InventoryComponent = world.storages.inventory("farm_supply_storage")
	_check(supplies.count_item(SEED.item_id) == 36, "36 seeds are in shared storage")
	store_menu.close(false)
	var progress: Dictionary = ToolUpgradeState.fresh()
	for key: String in progress:
		progress[key] = {"level": 6, "selected_size": 6}
	world.tool_upgrade_state.restore(progress)
	var origin: Vector2i = Vector2i(48, 30)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(origin))
	world.player.animation.face(Vector2.DOWN)
	world.player.camera.zoom = Vector2(2, 2)
	world.player.camera.position = Vector2(0, 48)
	world.player.camera.reset_smoothing()
	var cells: Array[Vector2i] = FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 6)
	world.farming.apply_area(&"tool", cells, null, -1, null, world.player)
	var plantable: int = 0
	for cell: Vector2i in cells:
		plantable += 1 if world.farming.can_plant(cell, world.player) else 0
	_check(plantable == 36, "Prepare actual 6x6 field")
	await _frames(8)
	await _click(world.seed_picker.launcher)
	_check(world.seed_picker.is_open, "PC button opens seed picker")
	await _capture("seed-picker-desktop")
	await _click(world.seed_picker.list.get_node("carrot_seed") as Button)
	_check(world.player.selection.storage_seed_id == SEED.item_id, "Seed selected with zero in bag")
	var ready: int = 0
	for row: Dictionary in world.player.farming_actions.preview():
		ready += 1 if row.ready else 0
	_check(ready == 36, "Preview reflects 36 stored seeds")
	await _capture("seed-preview-desktop")
	await _use()
	_check(world.farming.crop_cells().size() == 36, "Animation plants 36 crops")
	_check(supplies.count_item(SEED.item_id) == 0 and bag.count_item(SEED.item_id) == 0, "Exactly 36 stored seeds spent")
	await _capture("sown-desktop")
	world.player.selection.select_slot(0)
	_check(world.player.selection.storage_seed_id.is_empty(), "Hotbar exits storage seed mode")
	var food: AnimalTrough
	var pen: AnimalPen
	for candidate: AnimalPen in world.workers.bridge.pens():
		for node: Node in candidate.get_children():
			if node is AnimalTrough and node.kind == AnimalTrough.Kind.FOOD and node.feed_item.matches(FEED):
				food = node as AnimalTrough
				pen = candidate
				break
		if food != null:
			break
	food.stock = 0
	world.player.global_position = food.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	await _frames(10)
	var before: int = supplies.count_item(FEED.item_id)
	var target: InteractionTarget = InteractionTarget.new(food, InteractionTarget.Kind.TROUGH, world.player)
	_check(world.player.interactions.execute(target), "Player starts feed refill animation")
	await _frames(80)
	_check(food.stock > 0 and supplies.count_item(FEED.item_id) < before, "Player refills using shared feed")
	_check(bag.count_item(FEED.item_id) == 0, "Player feed action needs no bag token")
	for node: Node in pen.get_children():
		if node is AnimalTrough and node.kind == AnimalTrough.Kind.FOOD:
			node.stock = 0
	supplies.add(FEED, 8)
	_check(world.workers.hire("ranch", String(pen.persistent_id)).is_empty(), "Ranch hires with shared supplies")
	_check(world.workers.hire("crop").is_empty(), "Crop worker hires")
	var until: float = clock[0] + 600
	world.workers.advance(until)
	clock[0] = until
	_check(world.workers.bag_for("ranch").count_item(FEED.item_id) == 0, "Ranch uses no basket feed")
	_check(world.workers.output_inventory().count_item((SEED.crop as CropDefinition).harvest_item.item_id) > 0, "Sown crops reach produce warehouse through worker")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta("touch_ui_override", true)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(origin))
	world.player.animation.face(Vector2.DOWN)
	supplies.add(SEED, 3)
	await _frames(20)
	await _touch_click(world.seed_picker.launcher)
	_check(world.seed_picker.is_open, "Touch opens picker")
	_check(Rect2(Vector2.ZERO, world.seed_picker.root.size).encloses(world.seed_picker.panel.get_rect()), "Picker fits phone landscape")
	await _capture("seed-picker-touch")
	await _touch_click(world.seed_picker.list.get_node("carrot_seed") as Button)
	_check(world.player.selection.storage_seed_id == SEED.item_id, "Touch selects seed")
	await _touch_click(world.player.mobile_controls.tool_button)
	await _frames(80)
	_check(supplies.count_item(SEED.item_id) == 0, "Touch plants remaining three stored seeds")
	await _capture("sown-touch")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("supply_qa", 1, clock[0])
	_check(SaveSchema.validate(snapshot, adapter.catalog).ok, "v25 combined snapshot validates")
	_check(adapter.restore(snapshot, clock[0]).ok, "Combined snapshot restores")
	_check(world.player.selection.storage_seed_id == SEED.item_id, "Selected seed restores even when exhausted")
	var report: Dictionary = {"checks": _checks, "failures": _failures, "ok": _failures.is_empty(), "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _use() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"use_item"
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames(80)

func _touch_click(button: Button) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames(5)
