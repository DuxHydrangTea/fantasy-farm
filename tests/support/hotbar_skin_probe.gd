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

func _click(button: BaseButton) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion,true)
	await _frames(2)
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
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(8)
	world.tool_upgrades.profile_ready = true
	var hotbar: HotbarUI = world.player.get_node("Hotbar") as HotbarUI
	_check(hotbar.buttons.size() == 6,"Six hotbar slots retained")
	for button: InventorySlot in hotbar.buttons:
		_check(button.hotbar_skin,"Only hotbar uses new skin")
		_check((button.texture_normal as AtlasTexture).atlas.resource_path == "res://assets/Ui/hotbar.png","Hotbar uses supplied asset")
		_check((button.texture_normal as AtlasTexture).region == Rect2(6,6,52,52),"Normal frame cropped without transparent gutter")
		_check((button.texture_pressed as AtlasTexture).region == Rect2(70,6,52,52),"Selected frame uses white border")
	await _click(hotbar.buttons[1])
	_check(world.player.selection.selected_index == 1,"Mouse selects watering can")
	_check(not hotbar.buttons[1]._selection_frame.visible,"Old gold overlay removed from hotbar")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	get_viewport().push_input(key,true)
	await _frames()
	key.pressed = false
	get_viewport().push_input(key,true)
	_check(world.player.selection.selected_index == 0,"Number key selects first slot")
	await _capture("hotbar-new-desktop")
	await _click(hotbar.inventory_button)
	var bag: InventoryUI = world.player.get_node("InventoryUI") as InventoryUI
	_check(world.player.selection.inventory_open,"Bag button opens inventory")
	_check(not bag.buttons[0].hotbar_skin,"Bag grid retains its own skin")
	_check((bag.buttons[0].texture_normal as AtlasTexture).atlas.resource_path != "res://assets/Ui/hotbar.png","Bag art is unchanged")
	bag.close()
	get_viewport().set_meta("touch_ui_override",true)
	get_tree().root.size = Vector2i(844,390)
	await _frames(10)
	for button: InventorySlot in hotbar.buttons:
		_check(button.size.x == button.size.y,"Hotbar frame stays square on phone")
		_check(Rect2(Vector2.ZERO,hotbar.root.size).encloses(button.get_global_rect()),"Phone slot remains in viewport")
	await _touch_click(hotbar.buttons[1])
	_check(world.player.selection.selected_index == 1,"Touch selects second slot")
	await _capture("hotbar-new-phone-landscape")
	await _touch_click(hotbar.inventory_button)
	_check(world.player.selection.inventory_open,"Touch bag button opens inventory")
	bag.close()
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _touch_click(button: BaseButton) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames(5)
