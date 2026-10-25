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


func _run() -> void:
	_check(TranslationServer.get_locale().begins_with("vi"),"Game starts in Vietnamese")
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(8)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(13,4)
	world.player.wallet.set_balance(1000)
	world.objectives.progress.suspended = true
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	var board: OrderBoard = world.orders
	world.player.global_position = board.global_position+Vector2(0,24)
	world.player.animation.facing_direction = &"up"
	var bag: InventoryComponent = world.player.selection.inventory
	var serial: int = int(board.service.capture().slots[0].serial)
	var entry: OrderDefinition = board.service.definition(serial)
	for i: int in range(entry.items.size()):
		bag.add(entry.items[i],entry.amounts[i],0)
		bag.add(entry.items[i],entry.amounts[i]/2,1)
		bag.add(entry.items[i],entry.amounts[i]-entry.amounts[i]/2,2)
	await _frames(5)
	_check(board.open_board(world.player),"Order board opens")
	await _frames(8)
	var menu: OrderUI = board.menu
	_check(not menu.deliver_button.disabled and not menu.perfect_button.disabled,"Ordinary and Perfect choices both enabled")
	_check(menu.perfect_button.text.contains("Hoàn Hảo"),"Perfect button localized")
	await _click(menu.perfect_button)
	_check(menu.confirmation.visible,"Perfect confirmation opens")
	_check(menu._pending_plan.rows[0].tiers[0] == 0,"Perfect preview never consumes Normal")
	_check(menu.confirmation_text.text.contains("Bạc") and menu.confirmation_text.text.contains("Vàng"),"Preview shows exact tiers")
	await _capture("s5-perfect-desktop")
	await _click(menu.cancel_button)
	_check(board.service.definition(serial) != null and world.player.wallet.balance == 1000,"Cancel does not spend")
	await _click(menu.perfect_button)
	var expected_coins: int = int(menu._pending_plan.coins)
	await _click(menu.confirm_button)
	_check(world.player.wallet.balance == 1000+expected_coins,"Mouse perfect delivery pays guaranteed quality reward")
	_check(bag.count_item(entry.items[0].item_id,0) == entry.amounts[0],"Normal produce preserved")
	menu.close(false)
	get_tree().root.size = Vector2i(844,390)
	get_viewport().set_meta("touch_ui_override",true)
	await _frames(10)
	_check(board.open_board(world.player),"Phone landscape board opens")
	await _frames(10)
	_check(Rect2(Vector2.ZERO,menu.root.size).encloses(menu.panel.get_rect()),"Phone landscape board fits")
	await _capture("s5-orders-phone-landscape")
	await _touch_click(menu.close_button)
	_check(not menu.is_open,"Touch closes board")
	get_tree().root.size = Vector2i(720,960)
	await _frames(10)
	_check(board.open_board(world.player),"Phone portrait board opens")
	await _frames(10)
	_check(Rect2(Vector2.ZERO,menu.root.size).encloses(menu.panel.get_rect()),"Phone portrait board fits")
	await _capture("s5-orders-phone-portrait")
	await _touch_click(menu.close_button)
	get_tree().root.size = Vector2i(1280,720)
	var fertile: Vector2i = Vector2i.ZERO
	for y: int in range(19,53):
		for x: int in range(44,57):
			var cell: Vector2i = Vector2i(x,y)
			if fertile == Vector2i.ZERO and world.farming.fertility.is_fertile(cell) and world.farming.get_crop(cell) == null and not world.farming.cell_is_occupied(cell):
				fertile = cell
	_check(fertile != Vector2i.ZERO,"Open fertile test tile exists")
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(fertile))+Vector2(0,20)
	world.player.camera.zoom = Vector2(3,3)
	world.player.camera.reset_smoothing()
	bag.add(SEED,5)
	for i: int in range(bag.slot_count):
		if bag.slot(i).item == SEED:
			world.player.selection.selected_index = i
			break
	await _frames(10)
	_check((world.get_node("FertileSoil") as FertileSoilOverlay)._bright,"Fertile borders brighten while holding crop seeds")
	await _capture("s5-fertile-soil")
	var now: float = clock[0]
	world.farming.restore_crop(fertile,SEED.crop as CropDefinition,now-120,now-1,1,now,false,0,true,false)
	var before: int = bag.count_item((SEED.crop as CropDefinition).harvest_item.item_id,1)
	_check(world.farming.harvest(fertile,bag),"Fertile crop harvest succeeds")
	_check(bag.count_item((SEED.crop as CropDefinition).harvest_item.item_id,1)-before == 150,"Fertile carrot yields 150 Silver produce")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("s5_qa",1,now)
	_check(adapter.preflight(data).ok,"S5 save validates")
	_check(adapter.restore(data,now).ok,"S5 save restores")
	_check(world.farming.fertility.layout_version == 1,"Fertile layout version persists")
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
