extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const EGG: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
var world: FarmWorld
var _checks: int = 0
var _failures: Array[String] = []
var _output: String

class MemoryRepository extends SaveRepository:
	var snapshot: Dictionary = {}
	func read_profile(_profile: String) -> Dictionary:
		return {"ok": true, "found": not snapshot.is_empty(), "snapshot": snapshot.duplicate(true), "revision": snapshot.get("revision", 0)}
	func write_profile(_profile: String, data: Dictionary, _expected: int) -> Dictionary:
		snapshot = data.duplicate(true)
		return {"ok": true, "revision": data.revision}

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

func _use() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"use_item"
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames(80)

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
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.player.wallet.set_balance(1000000)
	var now: float = world.farming.time_manager.now()
	for index: int in range(10):
		var cell: Vector2i = Vector2i(12 + index * 3, 61)
		var tree: FruitTree = world.trees.trees.get(cell) as FruitTree
		if tree == null:
			tree = world.trees.create_tree(cell, world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1.0
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1.0
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds if index == 0 else 0.0
		tree.refresh(now)
	var board: WorkerBoard = world.get_node("OrchardWorkers") as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0, 24)
	await _frames(5)
	_check(world.player.shop_interaction.try_interact(), "E opens authored Orchard board")
	var menu: WorkerMenu = board.menu as WorkerMenu
	await _capture("orchard-board")
	await _click(menu.hire_button)
	_check(world.workers.actors.has("orchard"), "GUI hires orchard worker")
	menu.close(false)
	var worker: WorkerActor = world.workers.actors.orchard as WorkerActor
	world.player.global_position = worker.global_position + Vector2(0, 70)
	var start: Vector2 = worker.global_position
	await _frames(360)
	_check(worker.global_position.distance_to(start) > 2, "Worker physically walks toward task")
	_check(world.workers.output_inventory().count_item(&"apple") == 300 and worker.basket.count_item(&"apple") == 0, "Physical online worker sends 300 fruit to Warehouse after travel and work")
	world.player.global_position = worker.global_position + Vector2(0, 220)
	world.player.camera.position = Vector2(40, -200)
	world.player.camera.zoom = Vector2(3, 3)
	world.player.camera.reset_smoothing()
	await _capture("worker-harvesting-daylight")
	world.player.camera.zoom = Vector2(1.25, 1.25)
	world.player.camera.position = Vector2(584, 1168) - world.player.global_position
	world.player.camera.reset_smoothing()
	await _capture("orchard-overview-daylight")
	world.player.camera.position = Vector2.ZERO
	world.player.camera.zoom = Vector2(4, 4)
	world.player.camera.reset_smoothing()
	var access: WorkerBoard = worker.get_node("ManagementSign") as WorkerBoard
	world.player.global_position = worker.global_position + Vector2(0, 20)
	_check(access.open_shop(world.player), "E/click delegate opens worker basket")
	var basket_menu: WorkerMenu = access.menu as WorkerMenu
	await _frames(5)
	_check(basket_menu.collect_button.disabled, "Legacy recovery disabled when no old products remain")
	_check(basket_menu.info.text.contains(tr("Harvested products go directly to the produce warehouse.")), "Worker panel identifies Warehouse destination")
	_check(world.player.selection.inventory.count_item(&"apple") == 0, "New harvest never credits player bag")
	_check(worker.basket.count_item(&"apple") == 0, "Worker basket debited")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta(&"touch_ui_override", true)
	await _frames(10)
	_check(Rect2(Vector2.ZERO, basket_menu.root.size).encloses(basket_menu.panel.get_rect()), "Worker menu fits touch landscape")
	await _capture("touch-worker-basket")
	var scroll: ScrollContainer = basket_menu.dismiss_button.get_parent().get_parent() as ScrollContainer
	scroll.scroll_vertical = 10000
	await _frames(5)
	await _tap(basket_menu.dismiss_button)
	_check(world.workers.record("orchard").employed, "First touch asks dismissal confirmation")
	await _tap(basket_menu.dismiss_button)
	_check(not world.workers.record("orchard").employed, "Second touch dismisses while keeping basket")
	scroll.scroll_vertical = 0
	await _frames(5)
	await _tap(basket_menu.hire_button)
	_check(world.workers.record("orchard").employed, "Touch rehires the same role")
	basket_menu.close(false)
	_check(not world.player.selection.is_menu_open(), "Close releases player input")
	var before_coins: int = world.player.wallet.balance
	var target: float = world.farming.time_manager.now() + 172800.0
	var started: int = Time.get_ticks_usec()
	world.workers.advance(target)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var count: int = world.workers.output_inventory().count_item(&"apple")
	_check(count > 1600 and worker.basket.count_item(&"apple") == 0, "48h catch-up uses Warehouse beyond old basket limit")
	for i: int in range(worker.basket.slot_count):
		_check(worker.basket.get_slot_count(i) <= 100, "Catch-up slot cap " + str(i))
	get_tree().root.size = Vector2i(1280, 720)
	get_viewport().set_meta(&"touch_ui_override", false)
	var warehouse_access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = warehouse_access.global_position + Vector2(0, 24)
	await _frames(10)
	_check(warehouse_access.open_shop(world.player), "Warehouse opens after worker output")
	var warehouse_menu: FarmStorageMenu = warehouse_access.menu as FarmStorageMenu
	await _frames(5)
	await _capture("worker-output-warehouse")
	var apple_button: Button = warehouse_menu.grids[1].get_child(0) as Button
	await _click(apple_button)
	warehouse_menu.quantity.value = 300
	await _click(warehouse_menu.move_button)
	_check(world.player.selection.inventory.count_item(&"apple") == 300, "Player withdraws worker output from actual Warehouse UI")
	_check(world.workers.output_inventory().count_item(&"apple") == count - 300, "Warehouse debits exactly the withdrawn amount")
	warehouse_menu.close(false)
	var benchmark: Dictionary = {"offline_hours": 48, "elapsed_ms": elapsed_ms, "warehouse_apples": count, "wages_paid": before_coins - world.player.wallet.balance, "workers": 1, "fruit_trees": 10}
	var report: Dictionary = {"benchmark": benchmark, "checks": _checks, "failures": _failures, "personal_save_used": false, "ok": _failures.is_empty()}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	get_tree().quit(0 if _failures.is_empty() else 1)

func _tap(button: Button) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames(3)
