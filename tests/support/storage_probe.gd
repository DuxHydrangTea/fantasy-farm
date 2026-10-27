extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
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
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(APPLE, 50)
	bag.remove(SEED.item_id, bag.count_item(SEED.item_id))
	bag.remove(FEED.item_id, bag.count_item(FEED.item_id))
	bag.add(SEED, 24)
	bag.add(FEED, 5)
	var access: FarmStorageAccess = world.storage_accesses["produce_warehouse"]
	world.player.global_position = access.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	await _frames(10)
	_check(access.can_reach(world.player), "Produce doorway reachable")
	await _key(KEY_E)
	_check(access.menu.is_open, "E opens produce panel")
	if not access.menu.is_open:
		get_tree().quit(1)
		return
	var menu: FarmStorageMenu = access.menu as FarmStorageMenu
	await _frames(5)
	var apple_button: Button = _item_button(menu, APPLE.display_name, 0)
	_check(apple_button != null, "Produce item visible in bag")
	apple_button.grab_focus()
	await _key(KEY_ENTER)
	_check(menu.selected_id == APPLE.item_id, "Keyboard selects item without losing focus")
	_check(apple_button.has_focus(), "Item keeps keyboard focus")
	menu.quantity.value = 12
	await _click(menu.move_button)
	_check(world.storages.inventory("produce_warehouse").count_item(APPLE.item_id) == 12, "Mouse deposits selected amount")
	_check(bag.count_item(APPLE.item_id) == 38, "Source bag updated")
	_check(_item_button(menu, SEED.display_name, 0).disabled, "Seed disabled in produce warehouse")
	await _capture("produce-desktop")
	await _click(_item_button(menu, APPLE.display_name, 1))
	menu.quantity.value = 5
	await _click(menu.move_button)
	_check(world.storages.inventory("produce_warehouse").count_item(APPLE.item_id) == 7, "Mouse withdraws selected amount")
	await _click(menu.close_button)
	_check(not world.player.selection.shop_open, "Close releases player input")
	access = world.storage_accesses["farm_supply_storage"]
	world.player.global_position = access.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	await _frames(10)
	_check(access.open_shop(world.player), "Supply panel opens")
	menu = access.menu as FarmStorageMenu
	await _frames(5)
	_check(_item_button(menu, APPLE.display_name, 0).disabled, "Produce disabled in supply storage")
	await _click(_item_button(menu, SEED.display_name, 0))
	menu.quantity.value = 10
	await _click(menu.move_button)
	_check(world.storages.inventory("farm_supply_storage").count_item(SEED.item_id) == 10, "Supply deposits seed")
	await _capture("supply-desktop")
	get_viewport().set_meta("touch_ui_override", true)
	get_tree().root.size = Vector2i(844, 390)
	await _frames(20)
	await _touch_click(_item_button(menu, FEED.display_name, 0))
	menu.quantity.value = 2
	await _touch_click(menu.move_button)
	_check(world.storages.inventory("farm_supply_storage").count_item(FEED.item_id) == 2, "Touch deposits feed")
	_check(Rect2(Vector2.ZERO, menu.root.size).encloses(Rect2(menu.panel.position, menu.panel.size)), "Mobile panel fits viewport")
	_check(menu.grids[0].get_parent().size.y > 40, "Mobile list has visible rows")
	await _capture("supply-touch")
	await _touch_click(_item_button(menu, FEED.display_name, 1))
	await _touch_click(menu.move_button)
	_check(world.storages.inventory("farm_supply_storage").count_item(FEED.item_id) == 1, "Touch withdraws feed")
	await _touch_click(menu.close_button)
	_check(not world.player.selection.shop_open, "Touch close releases input")
	_check(access.open_shop(world.player), "Supply panel reopens")
	await _frames(5)
	await _touch_click(menu.find_child("DepositAll", true, false) as Button)
	_check(world.storages.inventory("farm_supply_storage").count_item(SEED.item_id) == 24, "Bulk deposit moves remaining seed")
	_check(bag.count_item(APPLE.item_id) == 43, "Bulk filter preserves produce in bag")
	await _touch_click(menu.find_child("WithdrawAll", true, false) as Button)
	_check(bag.count_item(SEED.item_id) == 24 and bag.count_item(FEED.item_id) == 5, "Bulk withdrawal restores all supply items")
	await _key(KEY_ESCAPE)
	_check(not menu.is_open, "Escape closes panel")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = world.farming.time_manager.now()
	var snapshot: Dictionary = adapter.capture("storage_qa", 1, now)
	_check(SaveSchema.validate(snapshot, adapter.catalog).ok, "Complete v24 snapshot validates")
	world.storages.inventory("produce_warehouse").remove(APPLE.item_id, 7)
	_check(adapter.restore(snapshot, now).ok, "Complete snapshot restores")
	_check(world.storages.inventory("produce_warehouse").count_item(APPLE.item_id) == 7, "Stored produce restored")
	var report: Dictionary = {"checks": _checks, "failures": _failures, "ok": _failures.is_empty()}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _item_button(menu: FarmStorageMenu, item_name: String, side: int) -> Button:
	for node: Node in menu.grids[side].get_children():
		if node is Button and String(node.get_meta("storage_name", "")) == item_name:
			return node as Button
	return null

func _touch_click(button: Button) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames(5)

func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames(5)
