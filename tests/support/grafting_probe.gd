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


func _open_chef(recipe_id: String) -> CookingMenu:
	var chef: ChefMerchant = world.get_node("Chef") as ChefMerchant
	world.player.global_position = chef.interaction_position() + Vector2(0, 24)
	await _frames(5)
	_check(chef.open_shop(world.player), "Chef opens for " + recipe_id)
	var menu: CookingMenu = chef.menu as CookingMenu
	menu._select(ChefCooking.find(recipe_id))
	await _frames(5)
	return menu

func _run() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(10)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(13, 4)
	world.player.wallet.set_balance(20000)
	world.objectives.progress.suspended = true
	world.trees.reset()
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	var definition: TreeDefinition = world.trees.definitions[&"apple"]
	var started: float = clock[0] - definition.growth_seconds - definition.fruit_cycle_seconds
	var tree: FruitTree = world.trees.create_tree(Vector2i(12, 61), definition, started) as FruitTree
	tree.growth_started_at = started
	tree.matures_at = started + definition.growth_seconds
	tree.refresh(clock[0])
	for i: int in range(1, 10):
		world.trees.create_tree(Vector2i(12 + i * 3, 61), definition, clock[0])
	world.player.global_position = tree.global_position + Vector2(0, 24)
	world.player.animation.facing_direction = &"up"
	world.player.camera.zoom = Vector2(3, 3)
	world.player.camera.reset_smoothing()
	await _frames(5)
	_check(not world.graft_menu.is_open, "Mature tree does not auto-open a modal")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	get_viewport().push_input(key, true)
	await _frames(1)
	key.pressed = false
	get_viewport().push_input(key, true)
	await _frames(8)
	var menu: GraftMenu = world.graft_menu
	_check(menu.is_open, "E opens mature tree graft menu")
	_check(menu.summary.text.contains("300"), "Current crop preview shows ordinary amount")
	await _capture("grafting-desktop-free")
	await _click(menu.yield_button)
	await _click(menu.confirm_button)
	_check(tree.pending_graft == FruitTree.Graft.YIELD and tree.active_graft == FruitTree.Graft.NONE, "Free choice schedules Yield without changing ripe fruit")
	await _click(menu.harvest_button)
	var bag: InventoryComponent = world.player.selection.inventory
	_check(bag.count_item(&"apple") == 300, "Current ordinary crop remains 300")
	_check(tree.active_graft == FruitTree.Graft.YIELD and tree.pending_graft == 0, "Harvest activates Yield for next cycle")
	await _capture("grafting-desktop-yield")
	menu.close(false)
	var recipe: CookingRecipe = ChefCooking.find("grafting_wax")
	for i: int in range(recipe.ingredients.size()):
		bag.add(recipe.ingredients[i], recipe.amounts[i])
	var cooking: CookingMenu = await _open_chef("grafting_wax")
	var before: int = world.player.wallet.balance
	_check((cooking.get_node("%Cost") as Label).text.contains(GameText.grouped_integer(1000)), "Wax coin cost preview shown")
	await _click(cooking.cook_button)
	_check(world.player.wallet.balance == before - 1000, "Wax crafting debits coins once")
	clock[0] += 61
	world.cooking.advance(clock[0])
	cooking._refresh()
	await _frames(5)
	await _click(cooking.collect_button)
	_check(bag.count_item(GraftService.WAX) == 1, "Chef delivers crafted wax")
	await _capture("grafting-wax-chef")
	cooking.close(false)
	world.player.global_position = tree.global_position + Vector2(0, 24)
	world.player.animation.facing_direction = &"up"
	await _frames(5)
	_check(world.player.interactions.click(tree.global_position + Vector2(0, -20)), "Click selects tree")
	await _frames(5)
	_check(menu.is_open, "Click reopens graft menu")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta("touch_ui_override", true)
	Language.set_language("vi")
	await _frames(35)
	_check(Rect2(Vector2.ZERO, menu.root.size).encloses(menu.panel.get_rect()), "Graft modal fits phone landscape")
	menu.browse.ensure_control_visible(menu.quality_button)
	await _frames(5)
	await _touch_click(menu.quality_button)
	await _touch_click(menu.confirm_button)
	_check(tree.active_graft == FruitTree.Graft.YIELD and tree.pending_graft == FruitTree.Graft.QUALITY, "Touch schedules Selection for following crop")
	_check(tree.harvest_amount() == 600 and tree.harvest_item() == definition.harvest_item, "Growing Yield crop stays ordinary 600")
	_check(bag.count_item(GraftService.WAX) == 0, "Changing direction spends one wax")
	await _touch_click(menu.confirm_button)
	_check(bag.count_item(GraftService.WAX) == 0 and tree.pending_graft == FruitTree.Graft.QUALITY, "Duplicate tap cannot spend again")
	await _capture("grafting-touch-pending")
	menu.close(false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var pending: Dictionary = adapter.capture("graft_qa", 1, clock[0])
	_check(SaveSchema.validate(pending, adapter.catalog).ok, "v30 pending snapshot validates")
	_check(adapter.restore(pending, clock[0]).ok, "Pending graft reloads")
	tree = world.trees.trees[Vector2i(12, 61)] as FruitTree
	_check(tree.pending_graft == FruitTree.Graft.QUALITY and tree.active_graft == FruitTree.Graft.YIELD, "Reload retains both directions")
	_check(world.workers.hire("crop").is_empty(), "Orchard worker hired")
	var until: float = clock[0] + 2 * definition.fruit_cycle_seconds + 120
	world.workers.advance(until)
	clock[0] = until
	var output: InventoryComponent = world.workers.output_inventory()
	_check(output.count_item(&"apple") == 600, "Worker delivers old Yield batch unchanged")
	_check(output.count_item(&"apple_star") >= 300, "Worker delivers next Star batch to Warehouse")
	_check(tree.active_graft == FruitTree.Graft.QUALITY and tree.pending_graft == 0, "Worker harvest applies pending graft")
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = access.global_position
	_check(world.storages.transfer("produce_warehouse", bag, &"apple_star", 2, false).ok, "Star fruit can be withdrawn without conversion")
	bag.add(load("res://items/honey/wild_honey.tres") as ItemDefinition, 1)
	cooking = await _open_chef("star_apple_tart")
	await _frames(8)
	_check(not cooking.cook_button.disabled, "Chef accepts exact Star ingredients")
	await _touch_click(cooking.cook_button)
	_check(world.cooking.queue.size() == 1, "Touch queues Star dish")
	clock[0] += 14401
	world.cooking.advance(clock[0])
	cooking._refresh()
	await _frames(8)
	await _touch_click(cooking.collect_button)
	_check(bag.count_item(&"star_apple_tart") == 1, "Star dish collected")
	cooking.browse.ensure_control_visible(cooking.details)
	await _frames(8)
	await _capture("grafting-star-dish-touch")
	cooking.close(false)
	var final_snapshot: Dictionary = adapter.capture("graft_qa", 2, clock[0])
	_check(SaveSchema.validate(final_snapshot, adapter.catalog).ok, "Final Star inventory and worker save validate")
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
