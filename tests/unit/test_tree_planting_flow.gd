extends GutTest

const WORLD: PackedScene = preload("res://world/main_world.tscn")

var world: FarmWorld
var now: float = 1793155000.0
var _old_source: Callable
var _old_floor: float

func before_each() -> void:
	_old_source = TimeManager.clock_source
	_old_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	world.farming.time_manager.clock_source = func() -> float: return now
	world.tool_upgrades.profile_ready = true
	world.tree_plot_upgrades.profile_ready = true
	world.player.wallet.set_balance(500000)
	world.trees.reset()
	world.tree_plot_upgrades.state.restore(TreePlotUpgradeState.fresh())

func after_each() -> void:
	TimeManager.clock_source = _old_source
	TimeManager._last_timestamp = _old_floor

func _unlocked_cell(kind: TreeDefinition.Kind, row: int = 0) -> Vector2i:
	var origin: Vector2i = TreePlantation.region_for(kind).position + Vector2i(2, 3)
	return origin + Vector2i(0, row * 3)

func _locked_cell(kind: TreeDefinition.Kind, row: int = 0) -> Vector2i:
	var origin: Vector2i = TreePlantation.region_for(kind).position + Vector2i(2, 3)
	return origin + Vector2i(3, row * 3)

func test_purchase_and_plant_for_fruit_and_timber_with_validation_and_reentrancy_guard() -> void:
	var fruit_cell: Vector2i = _unlocked_cell(TreeDefinition.Kind.FRUIT, 0)
	var timber_cell: Vector2i = _unlocked_cell(TreeDefinition.Kind.TIMBER, 0)
	var apple: TreeDefinition = world.trees.definitions[&"apple"]
	var oak: TreeDefinition = world.trees.definitions[&"oak"]
	# Place player safely away from both test cells.
	world.player.global_position = world.trees.point_for(_unlocked_cell(TreeDefinition.Kind.FRUIT, 5)) + Vector2(24, 0)
	await get_tree().physics_frame

	# Wrong region is rejected.
	assert_false(world.trees.quote_buy(timber_cell, apple, world.player.wallet).ok)
	assert_false(world.trees.quote_buy(fruit_cell, oak, world.player.wallet).ok)

	# Locked cell is rejected.
	assert_false(world.trees.quote_buy(_locked_cell(TreeDefinition.Kind.TIMBER, 0), oak, world.player.wallet).ok)

	# Insufficient coins is rejected.
	world.player.wallet.set_balance(apple.price - 1)
	assert_false(world.trees.purchase_and_plant(fruit_cell, apple, world.player.wallet, now).ok)
	assert_false(world.trees.trees.has(fruit_cell))
	assert_eq(world.player.wallet.balance, apple.price - 1)

	# Reentrancy guard blocks a nested purchase inside wallet.changed.
	world.player.wallet.set_balance(100000)
	var other_cell: Vector2i = _unlocked_cell(TreeDefinition.Kind.FRUIT, 1)
	var reentrant_results: Array[bool] = []
	var callback: Callable = func(_balance: int) -> void:
		reentrant_results.append(bool(world.trees.purchase_and_plant(other_cell, apple, world.player.wallet, now).ok))
	world.player.wallet.changed.connect(callback)
	var fruit_res: Dictionary = world.trees.purchase_and_plant(fruit_cell, apple, world.player.wallet, now)
	world.player.wallet.changed.disconnect(callback)
	assert_true(fruit_res.ok)
	assert_eq(reentrant_results, [false])
	assert_false(world.trees.trees.has(other_cell))
	assert_true(world.trees.trees.get(fruit_cell) is FruitTree)
	assert_eq(world.player.wallet.balance, 100000 - apple.price)

	# Occupied cell is rejected.
	assert_false(world.trees.quote_buy(fruit_cell, apple, world.player.wallet).ok)

	# Timber purchase & plant succeeds directly on unlocked timber cell.
	var timber_res: Dictionary = world.trees.purchase_and_plant(timber_cell, oak, world.player.wallet, now)
	assert_true(timber_res.ok)
	assert_true(world.trees.trees.get(timber_cell) is TimberTree)
	assert_eq(world.player.wallet.balance, 100000 - apple.price - oak.price)

func test_tree_plant_menu_uses_64x80_tree_sprites_and_plants_directly() -> void:
	var fruit_cell: Vector2i = _unlocked_cell(TreeDefinition.Kind.FRUIT, 0)
	var timber_cell: Vector2i = _unlocked_cell(TreeDefinition.Kind.TIMBER, 0)
	var menu: TreePlantMenu = world.tree_plant_menu

	# Test FRUIT menu: 4 cards, 64x80 sprite slots.
	world.player.global_position = world.trees.point_for(fruit_cell) + Vector2(24, 0)
	await get_tree().physics_frame
	assert_true(menu.open_plot(fruit_cell, TreeDefinition.Kind.FRUIT))
	assert_true(menu.is_open)
	assert_eq(menu.grid.get_child_count(), 4)
	for card: Button in menu.grid.get_children():
		var sprite: TextureRect = card.find_child("TreeSprite", true, false) as TextureRect
		assert_not_null(sprite)
		assert_eq(sprite.custom_minimum_size, Vector2(64, 80))
		assert_not_null(sprite.texture)
	menu.close(false)

	# Test TIMBER menu: 17 cards, 64x80 sprite slots, direct ready_texture, and direct purchase & plant.
	var start_coins: int = world.player.wallet.balance
	world.player.global_position = world.trees.point_for(timber_cell) + Vector2(24, 0)
	await get_tree().physics_frame
	assert_true(menu.open_plot(timber_cell, TreeDefinition.Kind.TIMBER))
	assert_eq(menu.grid.get_child_count(), 17)
	var expected_oak: TreeDefinition = world.trees.definitions[&"oak"]
	for card: Button in menu.grid.get_children():
		var sprite: TextureRect = card.find_child("TreeSprite", true, false) as TextureRect
		assert_not_null(sprite)
		assert_eq(sprite.custom_minimum_size, Vector2(64, 80))
		assert_not_null(sprite.texture)
	var first_sprite: TextureRect = menu.grid.get_child(0).find_child("TreeSprite", true, false) as TextureRect
	assert_eq(first_sprite.texture, expected_oak.ready_texture)
	menu.purchase()
	assert_false(menu.is_open)
	assert_true(world.trees.trees.get(timber_cell) is TimberTree)
	assert_eq((world.trees.trees.get(timber_cell) as TimberTree).definition, expected_oak)
	assert_eq(world.player.wallet.balance, start_coins - expected_oak.price)

func test_click_and_interact_on_unlocked_and_locked_plots() -> void:
	var unlocked: Vector2i = _unlocked_cell(TreeDefinition.Kind.TIMBER, 1)
	var locked: Vector2i = _locked_cell(TreeDefinition.Kind.TIMBER, 1)
	var unlocked_point: Vector2 = world.trees.point_for(unlocked)
	var locked_point: Vector2 = world.trees.point_for(locked)
	var resolver: InteractionResolver = world.player.interactions.resolver

	# Clicking unlocked empty plot returns Kind.TREE_PLOT.
	var clicked_unlocked: InteractionTarget = resolver.clicked(unlocked_point)
	assert_not_null(clicked_unlocked)
	assert_eq(clicked_unlocked.kind, InteractionTarget.Kind.TREE_PLOT)
	assert_eq(clicked_unlocked.cell, unlocked)
	assert_eq(clicked_unlocked.tree_kind, TreeDefinition.Kind.TIMBER)

	# Reachability rejects standing too far away and standing inside trunk footprint.
	assert_false(clicked_unlocked.reachable_from(unlocked_point + Vector2(60, 0)))
	assert_false(clicked_unlocked.reachable_from(unlocked_point))
	assert_true(clicked_unlocked.reachable_from(unlocked_point + Vector2(24, 0)))

	# Facing unlocked plot within reach resolves via E / Interact and opens TreePlantMenu.
	world.player.global_position = unlocked_point + Vector2(24, 0)
	world.player.animation.face(Vector2.LEFT)
	await get_tree().physics_frame
	world.player.interactions.refresh()
	assert_true(world.player.interactions.presenter.badge.visible)
	var resolved: InteractionTarget = resolver.resolve()
	assert_not_null(resolved)
	assert_eq(resolved.kind, InteractionTarget.Kind.TREE_PLOT)
	assert_eq(resolved.cell, unlocked)
	assert_true(world.player.interactions.press())
	assert_true(world.tree_plant_menu.is_open)
	world.tree_plant_menu.close(false)

	# Clicking or pressing E on locked plot opens TreePlotMenu directly.
	var clicked_locked: InteractionTarget = resolver.clicked(locked_point)
	assert_not_null(clicked_locked)
	assert_eq(clicked_locked.kind, InteractionTarget.Kind.TREE_PLOT)
	assert_false(clicked_locked.is_plot_unlocked())
	world.player.global_position = locked_point + Vector2(24, 0)
	world.player.animation.face(Vector2.LEFT)
	await get_tree().physics_frame
	assert_true(world.player.interactions.press())
	var timber_board: TreePlotBoard = world.trees.plot_boards[TreeDefinition.Kind.TIMBER]
	assert_true(timber_board.menu.is_open)
	timber_board.menu.close(false)

func test_click_walks_to_unlocked_and_locked_plots_then_opens_menus() -> void:
	var unlocked: Vector2i = _unlocked_cell(TreeDefinition.Kind.TIMBER, 2)
	var unlocked_point: Vector2 = world.trees.point_for(unlocked)
	var locked: Vector2i = _locked_cell(TreeDefinition.Kind.TIMBER, 2)
	var locked_point: Vector2 = world.trees.point_for(locked)

	# Walk from ~80 px away to unlocked empty plot, stop outside trunk footprint, open TreePlantMenu, and plant.
	world.player.global_position = unlocked_point + Vector2(80, 0)
	await get_tree().physics_frame
	assert_true(world.player.interactions.click(unlocked_point))
	assert_false(world.tree_plant_menu.is_open)
	for _frame: int in range(150):
		await get_tree().physics_frame
		if world.tree_plant_menu.is_open:
			break
	assert_true(world.tree_plant_menu.is_open)
	assert_false(TreePlantation.plot_footprint_rect(unlocked_point).has_point(world.player.global_position))
	world.tree_plant_menu.purchase()
	assert_false(world.tree_plant_menu.is_open)
	assert_true(world.trees.trees.get(unlocked) is TimberTree)

	# Walk from ~80 px away to locked empty plot and open TreePlotMenu on arrival.
	var timber_board: TreePlotBoard = world.trees.plot_boards[TreeDefinition.Kind.TIMBER]
	world.player.global_position = locked_point + Vector2(80, 0)
	await get_tree().physics_frame
	assert_true(world.player.interactions.click(locked_point))
	assert_false(timber_board.menu.is_open)
	for _frame: int in range(150):
		await get_tree().physics_frame
		if timber_board.menu.is_open:
			break
	assert_true(timber_board.menu.is_open)
	timber_board.menu.close(false)
