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
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	var chef: ChefMerchant = world.get_node("Chef") as ChefMerchant
	world.player.global_position = chef.interaction_position() + Vector2(0, 20)
	await _frames(5)
	_check(world.player.shop_interaction.try_interact(), "E interaction opens authored Chef")
	var menu: CookingMenu = chef.menu as CookingMenu
	world.player.selection.inventory.add(EGG, 3)
	await _frames()
	await _capture("desktop")
	await _click(menu.cook_button)
	_check(world.cooking.queue.size() == 1, "GUI cooking consumes one recipe")
	_check(world.player.selection.inventory.count_item(EGG.item_id) == 2, "Exactly one egg spent")
	clock[0] += 7200.0
	menu.close(false)
	chef.refresh_cooking_status()
	_check(chef.cooking_status.visible and absf(chef.cooking_progress.value - 50.0) < 0.1, "Overhead shows 50 percent halfway through dish")
	await _capture("overhead-cooking")
	_check(chef.open_shop(world.player), "Chef can reopen after viewing progress")
	clock[0] += 7200.0
	menu._refresh()
	await _frames()
	_check(world.cooking.ready.size() == 1, "Absolute timestamp completes dish")
	menu.close(false)
	chef.refresh_cooking_status()
	_check(chef.cooking_status.visible and chef.cooking_progress.value == 100.0, "Overhead shows ready dish after completion")
	await _capture("overhead-ready")
	_check(chef.open_shop(world.player), "Chef opens to collect completed dish")
	await _click(menu.collect_button)
	_check(world.player.selection.inventory.count_item(&"fried_egg") == 1, "GUI collection grants output")
	_check(world.cooking.ready.is_empty(), "Collected dish removed from Chef")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta(&"touch_ui_override", true)
	await _frames(15)
	menu._refresh()
	await _frames()
	_check(Rect2(Vector2.ZERO, menu.root.size).encloses(menu.panel.get_rect()), "Touch panel fits: root=%s panel=%s min=%s" % [menu.root.size, menu.panel.get_rect(), menu.panel.get_combined_minimum_size()])
	await _capture("touch")
	menu.browse.scroll_vertical = 1000
	await _frames(8)
	await _capture("touch-ingredients")
	_check(menu.quantity.is_visible_in_tree(), "Touch quantity row remains available by scrolling")
	var button: Button = menu.cook_button
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames()
	_check(world.cooking.queue.size() == 1, "ScreenTouch queues a dish exactly once")
	menu.close(false)
	_check(not world.player.selection.is_menu_open(), "Close releases modal input")
	var report: Dictionary = {"checks": _checks, "failures": _failures, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	get_tree().quit(0 if _failures.is_empty() else 1)
