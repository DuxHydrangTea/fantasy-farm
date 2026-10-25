extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
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
	world.land.state.restore_columns(12, 4)
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.farming.restore_soil([])
	var fields: Array[Vector2i] = [Vector2i(48, 30), Vector2i(49, 30), Vector2i(50, 30)]
	for y: int in range(LandExpansionState.REGION.position.y, LandExpansionState.REGION.end.y):
		for x: int in range(LandExpansionState.REGION.position.x, LandExpansionState.REGION.end.x):
			var point: Vector2i = Vector2i(x, y)
			if point not in fields:
				world.farming.set_cell_occupied(point, true)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.remove(SEED.item_id, bag.count_item(SEED.item_id))
	bag.add(SEED, 2)
	bag.add(OTHER, 1)
	bag.add(FERTILIZER, 3)
	var access: FarmStorageAccess = world.storage_accesses.farm_supply_storage
	world.player.global_position = access.global_position + Vector2(0, 24)
	await _frames(8)
	_check(access.open_shop(world.player), "Supply warehouse opens")
	await _frames(5)
	var menu: FarmStorageMenu = access.menu as FarmStorageMenu
	await _click(menu.find_child("DepositAll", true, false) as Button)
	var supplies: InventoryComponent = world.storages.inventory("farm_supply_storage")
	_check(supplies.count_item(FERTILIZER.item_id) == 3, "Warehouse GUI accepts fertilizer")
	_check(supplies.count_item(SEED.item_id) == 2 and supplies.count_item(OTHER.item_id) == 1, "Mixed seeds stored")
	menu.close(false)
	var board: WorkerBoard = world.get_node("CropWorkers") as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0, 24)
	await _frames(8)
	_check(board.open_shop(world.player), "Crop board opens")
	var worker_menu: WorkerMenu = board.menu as WorkerMenu
	await _frames(5)
	await _click(worker_menu.hire_button)
	_check(not world.workers.record("crop").is_empty(), "GUI hires crop worker")
	_check(world.workers.crop_automation.auto_plant, "Auto till and replant enabled on new hire")
	await _click(worker_menu.auto_fertilize_button)
	_check(world.workers.crop_automation.auto_fertilize, "GUI enables fertilizer")
	await _capture("crop-settings-desktop")
	worker_menu.close(false)
	var worker: WorkerActor = world.workers.actors.crop as WorkerActor
	var start: Vector2 = worker.global_position
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(49, 35)))
	world.player.camera.zoom = Vector2(3, 3)
	world.player.camera.position = Vector2(0, -55)
	world.player.camera.reset_smoothing()
	var frames: int = 0
	while (world.workers.crop_automation.sequence < 3 or supplies.count_item(FERTILIZER.item_id) > 0) and frames < 3300:
		await _frames(15)
		frames += 15
	_check(worker.global_position.distance_to(start) > 8, "Worker physically walks on full map")
	_check(world.workers.crop_automation.sequence == 3, "Online worker tills and plants three actual plots")
	_check(supplies.count_item(SEED.item_id) == 0 and supplies.count_item(OTHER.item_id) == 0, "One seed spent per successful plot across seed types")
	_check(supplies.count_item(FERTILIZER.item_id) == 0, "Online worker applies stored fertilizer")
	_check(bag.count_item(SEED.item_id) == 0 and bag.count_item(OTHER.item_id) == 0, "No bag token needed")
	var fertilized: int = 0
	for cell: Vector2i in world.farming.crop_cells():
		fertilized += 1 if world.farming.get_crop(cell).fertilized else 0
	_check(fertilized == 3, "All worker crops fertilized exactly once")
	await _capture("crop-worker-field")
	var worker_access: WorkerBoard = worker.get_node("ManagementSign") as WorkerBoard
	world.player.global_position = worker.global_position + Vector2(0, 24)
	_check(worker_access.open_shop(world.player), "Worker management opens")
	worker_menu = worker_access.menu as WorkerMenu
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta("touch_ui_override", true)
	await _frames(15)
	_check(Rect2(Vector2.ZERO, worker_menu.root.size).encloses(worker_menu.panel.get_rect()), "Crop settings fit touch landscape")
	await _touch_click(worker_menu.pause_crop_button)
	_check(world.workers.crop_automation.paused, "Touch pauses crop work")
	var paused_at: Vector2 = worker.global_position
	await _frames(12)
	_check(worker.global_position.distance_to(paused_at) < 1, "Paused worker stays still")
	await _capture("crop-settings-touch")
	await _touch_click(worker_menu.pause_crop_button)
	_check(not world.workers.crop_automation.paused, "Touch resumes crop work")
	worker_menu.close(false)
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	supplies.add(SEED, 1)
	var until: float = clock[0] + 300
	world.workers.advance(until)
	clock[0] = until
	_check(world.workers.crop_automation.sequence == 4, "Harvested field is replanted without seed selection")
	_check(supplies.count_item(SEED.item_id) == 0, "Replant spends exactly one new seed")
	_check(world.workers.output_inventory().count_item((SEED.crop as CropDefinition).harvest_item.item_id, -1) == 3 * (SEED.crop as CropDefinition).harvest_amount, "Carrot yield goes directly to Warehouse")
	_check(world.workers.output_inventory().count_item((OTHER.crop as CropDefinition).harvest_item.item_id, -1) == (OTHER.crop as CropDefinition).harvest_amount, "Second crop type reaches Warehouse")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("crop_worker_qa", 1, clock[0])
	_check(SaveSchema.validate(snapshot, adapter.catalog).ok, "Current snapshot validates")
	var stock: Dictionary = world.storages.capture()
	_check(adapter.restore(snapshot, clock[0]).ok, "Current snapshot restores")
	_check(world.workers.crop_automation.sequence == 4 and world.workers.crop_automation.auto_fertilize, "Automation history and settings restore")
	_check(world.storages.capture() == stock, "Reload never duplicates produce or spends more supplies")
	var report: Dictionary = {"checks": _checks, "failures": _failures, "ok": _failures.is_empty(), "online_frames": frames, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _touch_click(button: Button) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames(5)
