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


func _hive(slot: int) -> Beehive:
	for hive: Beehive in world.apiary.hives:
		if hive.garden_slot == slot:
			return hive
	return null

func _run() -> void:
	Language.set_language("vi")
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(8)
	world.honey_garden.set_process(false)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(13,4)
	world.player.wallet.set_balance(5000)
	world.objectives.progress.suspended = true
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	_check(world.honey_garden.try_migrate(),"Garden converted")
	var garden: FlowerGarden = world.apiary.gardens[0]
	_check(garden.pots.size() == 112,"Four equal 7x4 blocks contain 112 positions")
	for pot: FlowerPot in garden.pots.values():
		pot.clear()
	for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var pot: FlowerPot = garden.pots[Vector2i(4,2)+offset]
		var species: int = 1 if offset.x != 0 else 6
		var path: String = "res://flowers/definitions/flower_%02d.tres" % species
		var flower: FlowerDefinition = load(path) as FlowerDefinition
		pot.restore_state({"planted_at":clock[0]-100,"growth_started_at":clock[0]-100,"matures_at":clock[0]-1,"progress":1.0},flower,clock[0])
	clock[0] += 1
	world.apiary.advance(clock[0])
	var hive: Beehive = _hive(1)
	world.player.global_position = hive.global_position + Vector2(0,10)
	world.player.animation.facing_direction = &"up"
	world.player.camera.zoom = Vector2(3,3)
	world.player.camera.reset_smoothing()
	await _frames(8)
	_check(hive.production.batch_recipe == "hybrid_01_06","Hybrid locks at batch start")
	_check(not world.honey_menu.is_open,"Journal does not auto-open")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	get_viewport().push_input(key,true)
	await _frames()
	key.pressed = false
	get_viewport().push_input(key,true)
	await _frames(8)
	_check(world.honey_menu.is_open,"E opens bee journal")
	_check(world.honey_menu.recipe_rows.size() == 5,"Five recipes visible from start")
	_check((world.honey_menu.recipe_rows[0].get_child(0) as TextureRect).modulate == Color(0,0,0,1),"Uncooked jar silhouette")
	await _capture("bee-journal-desktop")
	world.honey_menu.close(false)
	world.player.camera.zoom = Vector2(2,2)
	await _capture("bee-garden-layout")
	clock[0] += 86400
	world.apiary.advance(clock[0])
	_check(hive.production.ready_item == HoneyComboCatalog.item("hybrid_01_06"),"Full hybrid batch ready")
	_check(world.honey_menu.open_hive(hive),"Reopen journal")
	await _frames(6)
	await _click(world.honey_menu.harvest_button)
	_check(world.player.selection.inventory.count_item(&"hybrid_01_06_honey") == 100,"Mouse collects full 100-jar batch")
	world.honey_menu.close(false)
	var outer: Beehive = _hive(0)
	world.player.global_position = outer.global_position + Vector2(0,10)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(load("res://items/trees/wood.tres") as ItemDefinition,15)
	await _frames(5)
	_check(world.honey_menu.open_hive(outer),"Open rotten outer hive")
	await _frames(8)
	await _capture("bee-repair-desktop")
	await _click(world.honey_menu.repair_button)
	_check(outer.repaired,"Mouse repairs outer hive")
	_check(bag.count_item(&"wood") == 0 and world.player.wallet.balance == 4500,"Repair charges 15 wood and 500 coins")
	world.honey_menu.close(false)
	get_tree().root.size = Vector2i(720,960)
	get_viewport().set_meta("touch_ui_override",true)
	await _frames(10)
	_check(world.honey_menu.open_hive(outer),"Touch-sized journal opens")
	await _frames(10)
	_check(world.honey_menu.panel.size.x <= 696,"Portrait modal fits width")
	_check(world.honey_menu.harvest_button.size.y >= 64,"Touch target minimum height")
	await _capture("bee-journal-touch")
	await _touch_click(world.honey_menu.close_button)
	_check(not world.honey_menu.is_open,"Touch closes journal")
	get_tree().root.size = Vector2i(844,390)
	await _frames(10)
	_check(world.honey_menu.open_hive(outer),"Landscape phone journal opens")
	await _frames(10)
	_check(Rect2(Vector2.ZERO,world.honey_menu.root.size).encloses(world.honey_menu.panel.get_rect()),"Landscape modal stays inside phone viewport")
	await _capture("bee-journal-phone-landscape")
	await _touch_click(world.honey_menu.close_button)
	_check(not world.honey_menu.is_open,"Landscape touch closes journal")
	get_tree().root.size = Vector2i(720,960)
	await _frames(10)
	bag.add(load("res://items/animal_produces/cow_milk.tres") as ItemDefinition,1)
	var chef: ChefMerchant = world.get_node("Chef") as ChefMerchant
	world.player.global_position = chef.interaction_position()+Vector2(0,24)
	await _frames(8)
	_check(chef.open_shop(world.player),"Chef opens")
	var cooking: CookingMenu = chef.menu as CookingMenu
	cooking._select(ChefCooking.find("hybrid_01_06_custard"))
	await _frames(8)
	await _touch_click(cooking.cook_button)
	_check(world.cooking.queue.size() == 1,"Touch queues honey custard")
	clock[0] += 14401
	world.cooking.advance(clock[0])
	cooking._refresh()
	await _frames(8)
	await _touch_click(cooking.collect_button)
	_check(bag.count_item(&"hybrid_01_06_custard") == 1,"Touch collects custard")
	_check("hybrid_01_06" in world.honey_garden.discoveries,"Successful Chef collection reveals jar")
	cooking.close(false)
	world.player.global_position = outer.global_position+Vector2(0,10)
	await _frames(8)
	_check(world.honey_menu.open_hive(outer),"Reopen journal after cooking")
	await _frames(8)
	_check((world.honey_menu.recipe_rows[0].get_child(0) as TextureRect).modulate == Color.WHITE,"Cooked jar icon revealed")
	await _capture("bee-jar-revealed-touch")
	world.honey_menu.close(false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("honey_qa",1,clock[0])
	_check(adapter.preflight(data).ok,"Native final save validates")
	_check(adapter.restore(data,clock[0]).ok,"Native final save restores")
	_check(world.apiary.hives.size() == 3,"Reload does not duplicate hives")
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
