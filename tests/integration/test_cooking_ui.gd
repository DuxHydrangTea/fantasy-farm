extends GutTest
var viewport: SubViewport
var world: FarmWorld
var menu: CookingMenu
var clock: Array[float]
var previous_clock: Callable
var previous_floor: float

func before_each() -> void:
	previous_clock = TimeManager.clock_source
	previous_floor = TimeManager._last_timestamp
	clock = [TimeManager.now()]
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	viewport.add_child(world)
	world.tool_upgrades.profile_ready = true
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	world.cooking.restore(ChefCooking.fresh(), clock[0])
	world.player.wallet.set_balance(1000000)
	var chef: ChefMerchant = world.get_node("Chef") as ChefMerchant
	world.player.global_position = chef.interaction_position() + Vector2(0, 20)
	menu = chef.menu as CookingMenu
	assert_true(chef.open_shop(world.player))
	await wait_process_frames(3)

func after_each() -> void:
	TimeManager.clock_source = previous_clock
	TimeManager._last_timestamp = previous_floor
	Language.set_language("en")

func test_filter_and_maximum_track_actual_ingredients_and_shared_capacity() -> void:
	menu._filter(true)
	assert_true((menu.get_node("%EmptyRecipes") as Label).visible)
	var egg: ItemDefinition = ChefCooking.RECIPES[0].ingredients[0]
	world.player.selection.inventory.add(egg, 30)
	assert_true(menu.recipe_buttons[0].visible)
	menu._set_maximum()
	assert_eq(int(menu.quantity.value), 20)
	menu._cook()
	assert_eq(world.cooking.queue.size(), 20)
	assert_eq(world.player.selection.inventory.count_item(egg.item_id), 10)
	assert_true(menu.cook_button.disabled)
	assert_true((menu.get_node("%Maximum") as Button).disabled)
	assert_true((menu.get_node("%EmptyRecipes") as Label).visible)

func test_ready_collection_refreshes_queue_and_does_not_duplicate() -> void:
	world.player.selection.inventory.add(ChefCooking.RECIPES[0].ingredients[0], 3)
	menu.quantity.value = 3
	menu._cook()
	clock[0] += ChefCooking.RECIPES[0].cook_seconds * 1.5
	menu._refresh()
	assert_eq(world.cooking.ready.size(), 1)
	assert_eq(world.cooking.queue.size(), 2)
	assert_almost_eq(menu.progress.value, 50.0, 0.01)
	assert_false(menu.collect_button.disabled)
	menu._collect()
	assert_eq(world.player.selection.inventory.count_item(&"fried_egg"), 1)
	assert_true(menu.collect_button.disabled)
	menu._collect()
	assert_eq(world.player.selection.inventory.count_item(&"fried_egg"), 1)

func test_paid_recipe_maximum_obeys_quality_wallet_and_live_model_updates() -> void:
	var recipe: CookingRecipe = ChefCooking.find("grafting_wax")
	menu._select(recipe)
	assert_true(menu.cook_button.disabled)
	for i: int in range(recipe.ingredients.size()):
		world.player.selection.inventory.add(recipe.ingredients[i], recipe.amounts[i] * 2, recipe.tier_at(i))
	world.player.wallet.set_balance(recipe.coin_cost)
	assert_eq(menu._maximum_for(recipe), 1)
	menu._set_maximum()
	assert_false(menu.cook_button.disabled)
	menu._cook()
	assert_eq(world.player.wallet.balance, 0)
	assert_eq(world.cooking.queue.size(), 1)
	assert_true(menu.cook_button.disabled)
	assert_eq(menu._maximum_for(recipe), 0)

func test_compact_layout_keeps_actions_visible_and_restores_desktop_columns() -> void:
	Language.set_language("vi")
	viewport.set_meta(&"touch_ui_override", true)
	viewport.size = Vector2i(667, 375)
	await wait_process_frames(8)
	assert_false((menu.get_node("%DetailPanel") as PanelContainer).visible)
	assert_eq(menu.get_node("%DetailContent").get_parent(), menu.get_node("%ActionContent"))
	for control: Control in [menu.panel, menu.close_button, menu.cook_button, menu.collect_button]:
		assert_true(Rect2(Vector2.ZERO, menu.root.size).grow(1).encloses(control.get_global_rect()))
	assert_gte(menu.cook_button.size.y, 48.0)
	viewport.set_meta(&"touch_ui_override", false)
	viewport.size = Vector2i(1280, 720)
	await wait_process_frames(8)
	assert_true((menu.get_node("%DetailPanel") as PanelContainer).visible)
	assert_eq(menu.get_node("%DetailContent").get_parent(), menu.get_node("%DetailScroll"))
	menu.close(false)
	assert_false(world.player.selection.shop_open)

func test_switching_recipes_after_changing_quantity_rebuilds_ingredient_rows() -> void:
	menu._select(ChefCooking.find("bread"))
	menu.quantity.value = 4
	menu._select(ChefCooking.find("fried_egg"))
	assert_eq(menu._ingredient_counts.size(), 1)
	assert_eq(int(menu.quantity.value), 1)
	assert_eq(menu.product_name.text, tr("Fried Egg"))
	menu._select(ChefCooking.find("star_apple_tart_batch"))
	assert_eq(menu._ingredient_counts.size(), menu.selected.ingredients.size())
