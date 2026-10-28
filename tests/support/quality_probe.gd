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
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(10)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.farming.restore_soil([])
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	var bag: InventoryComponent = world.player.selection.inventory
	var supply: InventoryComponent = world.storages.inventory("farm_supply_storage")
	supply.add(SEED, 3)
	var fields: Array[Vector2i] = [Vector2i(48, 30), Vector2i(49, 30), Vector2i(50, 30)]
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(49, 33)))
	_check(world.farming.apply_area(&"tool", fields, null, -1, null, world.player).changed == 3, "Three plots tilled")
	_check(world.farming.apply_area(&"plant", fields, supply, -1, SEED, world.player, true).changed == 3, "Three crops planted from supplies")
	_check(world.farming.water(fields[1], world.player), "One crop watered for Silver")
	_check(world.farming.water(fields[2], world.player), "Second crop watered for Gold")
	var root: ItemDefinition = load("res://items/trees/root_wood.tres") as ItemDefinition
	bag.add(root, 1)
	var chef: ChefMerchant = world.get_node("Chef") as ChefMerchant
	world.player.global_position = chef.interaction_position() + Vector2(0, 24)
	await _frames(5)
	_check(chef.open_shop(world.player), "Chef opens")
	var cooking: CookingMenu = chef.menu as CookingMenu
	cooking._select(ChefCooking.find("root_tonic"))
	await _frames(5)
	_check(cooking.details.text.contains("60"), "Root Tonic duration preview")
	await _click(cooking.cook_button)
	_check(world.cooking.queue.size() == 1, "Root Tonic queued with GUI")
	clock[0] += 61
	world.cooking.advance(clock[0])
	cooking._refresh()
	await _frames(5)
	await _click(cooking.collect_button)
	_check(bag.count_item(&"root_tonic") == 1, "Crafted tonic collected")
	await _capture("root-tonic-chef")
	cooking.close(false)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(50, 32)))
	await _frames(5)
	var tonic: ItemDefinition = load("res://items/boosters/root_tonic.tres") as ItemDefinition
	var index: int = -1
	for i: int in range(bag.slot_count):
		if bag.get_slot_item(i) == tonic:
			index = i
	var command: BoosterService = BoosterService.new()
	_check(command.use(world.farming, fields[2], null, bag, index, tonic, world.player).ok, "Root Tonic applies through player command")
	var crop: Crop = world.farming.get_crop(fields[2])
	crop.set_status_focused(true)
	_check(crop.quality_particles != null and crop.quality_particles.emitting, "Gold particles displayed on crop")
	world.player.camera.zoom = Vector2(3, 3)
	world.player.camera.reset_smoothing()
	await _capture("quality-field")
	for tier: int in range(3):
		_check(world.farming.get_crop(fields[tier]).harvest_tier() == tier, "Field quality tier " + str(tier))
		_check(world.farming.harvest(fields[tier], bag), "Harvest tier " + str(tier))
	var produce: ItemDefinition = SEED.crop.harvest_item as ItemDefinition
	var amount: int = (SEED.crop as CropDefinition).harvest_amount
	for tier: int in range(3):
		_check(bag.count_item(produce.item_id, tier) == amount, "Yield preserved for tier " + str(tier))
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = access.global_position
	await _frames(5)
	_check(access.open_shop(world.player), "Warehouse opens")
	var store_menu: FarmStorageMenu = access.menu as FarmStorageMenu
	await _frames(5)
	await _click(store_menu.find_child("DepositAll", true, false) as Button)
	var output: InventoryComponent = world.storages.inventory("produce_warehouse")
	for tier: int in range(3):
		_check(output.count_item(produce.item_id, tier) == amount, "Deposit preserves tier " + str(tier))
	await _capture("quality-warehouse-desktop")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta("touch_ui_override", true)
	await _frames(15)
	_check(Rect2(Vector2.ZERO, store_menu.root.size).encloses(store_menu.panel.get_rect()), "Warehouse fits touch")
	await _capture("quality-warehouse-touch")
	await _touch_click(store_menu.find_child("WithdrawAll", true, false) as Button)
	_check(bag.count_item(produce.item_id, 2) == amount, "Touch withdrawal preserves Gold")
	store_menu.close(false)
	var bag_ui: InventoryUI = world.player.get_node("InventoryUI") as InventoryUI
	bag_ui.open()
	await _frames(8)
	var produce_slot: int = -1
	for i: int in range(bag.slot_count):
		if bag.get_slot_item(i) == produce:
			produce_slot = i
	_check(produce_slot >= 0, "Produce has a bag slot")
	await _touch_click(bag_ui.buttons[produce_slot])
	_check(bag_ui.quality_panel.is_visible_in_tree(), "Touch shows inline three-tier breakdown")
	_check(bag_ui._quality_rows[2].text.contains(str(amount)), "Gold count shown in breakdown")
	await _capture("quality-bag-touch")
	bag_ui.close()
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	world.player.global_position = buyer.interaction_position() + Vector2(0, 24)
	await _frames(5)
	_check(buyer.open_shop(world.player), "Sales opens on touch")
	var sales: ProduceSalesUI = buyer.menu as ProduceSalesUI
	sales._choose_tier(1)
	await _frames(5)
	_check(sales.sell_all_button.text.contains(ItemQuality.label(1)), "Sale preview names Silver tier")
	await _capture("quality-sales-touch")
	await _touch_click(sales.sell_all_button)
	_check(bag.count_item(produce.item_id, 1) == 0, "Touch sells selected Silver")
	_check(bag.count_item(produce.item_id, 2) == amount, "Sale preserves unselected Gold")
	sales.close(false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("quality_qa", 1, clock[0])
	_check(SaveSchema.validate(snapshot, adapter.catalog).ok, "Quality save validates")
	_check(adapter.restore(snapshot, clock[0]).ok, "Quality save restores")
	_check(world.player.selection.inventory.count_item(produce.item_id, 2) == amount, "Restore retains Gold exactly")
	var report: Dictionary = {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
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
