extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var ui: HelpUI
var viewport: SubViewport

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.set_meta(&"touch_layout", true)
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(844, 390)
	viewport.size_2d_override = Vector2i(2337, 1080)
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(world)
	await wait_physics_frames(2)
	ui = world.help_ui

func after_each() -> void:
	Language.set_language("en")

func test_help_and_skip_do_not_complete_or_reward_goals_and_modal_excludes_bag() -> void:
	var before: Dictionary = world.objectives.progress.capture()
	ui.open_help()
	assert_true(ui.is_open)
	assert_true(world.tutorial.seen("first_soil"))
	world.player.selection.set_inventory_open(true)
	world.objective_ui.open()
	assert_false(world.player.selection.inventory_open)
	assert_false(world.player.selection.objectives_open)
	ui.skip_button.pressed.emit()
	assert_true(world.tutorial.capture().skipped)
	assert_eq(world.objectives.progress.capture(), before)
	assert_eq(world.player.wallet.balance, WalletComponent.STARTING_COINS)
	ui.close()
	assert_false(world.tutorial_hints.button.visible)
	world.tutorial.set_enabled(true)
	assert_true(world.tutorial.seen("first_soil"), "Re-enabling does not replay read tips")

func test_context_follows_real_success_and_hint_timer_never_completes_gameplay() -> void:
	var hint: TutorialHints = world.tutorial_hints
	hint._timer.wait_time = 0.01
	hint._timer.start()
	await wait_seconds(0.05)
	assert_true(world.tutorial.seen("first_soil"))
	assert_eq(world.objectives.progress.progress(), 0)
	world.objectives.progress.state_query = func(_condition: StringName) -> int: return 1
	world.objectives.progress.refresh_state()
	assert_true(world.objectives.progress.claim(&"first_soil").ok)
	assert_true(hint.button.visible)
	assert_true(hint.label.text.contains("Stored seeds"))
	assert_false(world.tutorial.seen("first_seed"))
	viewport.size = Vector2i(375, 667)
	viewport.size_2d_override = Vector2i(607, 1080)
	(world.objective_ui.get_node("UIScale") as UIScaleComponent).refresh()
	hint.refresh()
	assert_false(hint.button.visible, "Portrait rotation notice must not count as viewing a hint")
	hint._seen()
	assert_false(world.tutorial.seen("first_seed"))

func test_supply_audit_and_one_time_recovery_with_save_load() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	assert_gte(bag.count_item(&"carrot_seed"), 12)
	assert_gte(bag.capacity_for(StarterSupport.SEED), 1)
	assert_false(ui.support.quote().ok)
	for index: int in range(bag.slot_count):
		var item: ItemDefinition = bag.get_slot_item(index)
		if item != null and item.item_type == ItemDefinition.ItemType.SEED:
			bag.remove(item.item_id, bag.count_item(item.item_id))
	world.player.wallet.set_balance(0)
	assert_true(ui.support.quote().ok)
	var before: Dictionary = world.objectives.progress.capture()
	assert_true(ui.support.claim().ok)
	assert_false(ui.support.claim().ok)
	assert_eq(bag.count_item(&"carrot_seed"), 1)
	assert_eq(world.player.wallet.balance, 0)
	assert_eq(world.objectives.progress.capture(), before)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("help_test", 1, TimeManager.now())
	ui.open_help()
	assert_true(adapter.restore(saved, TimeManager.now()).ok)
	assert_false(ui.is_open)
	assert_true(world.tutorial.capture().support_used)
	assert_false(ui.support.claim().ok)

func test_migration_seen_preferences_and_corrupt_preflight() -> void:
	world.tutorial.mark_seen("first_soil")
	world.tutorial.skip()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("help_test", 1, TimeManager.now())
	world.tutorial.set_enabled(true)
	assert_true(adapter.restore(saved, TimeManager.now()).ok)
	assert_true(world.tutorial.capture().skipped)
	assert_true(world.tutorial.seen("first_soil"))
	var bad: Dictionary = saved.duplicate(true)
	bad.tutorial.seen = ["unknown"]
	assert_false(adapter.restore(bad, TimeManager.now()).ok)
	assert_eq(world.tutorial.capture(), saved.tutorial)
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 14
	legacy.erase("tutorial")
	legacy.orders = OrderSaveSchema.fresh()
	assert_true(adapter.restore(legacy, TimeManager.now()).ok)
	assert_true(world.tutorial.capture().enabled)
	assert_false(legacy.has("tutorial"))

func test_recovery_blocked_by_planted_crops_or_a_full_bag() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	bag.remove(&"carrot_seed", bag.count_item(&"carrot_seed"))
	world.player.wallet.set_balance(0)
	var filled: Array[Dictionary] = []
	var feed: ItemDefinition = load("res://items/feeds/poultry_feed.tres") as ItemDefinition
	assert_not_null(feed)
	if feed == null:
		return
	for index: int in range(bag.slot_count):
		filled.append({"item": feed, "count": feed.get_stack_limit()})
	assert_true(bag.replace_slots(filled))
	assert_false(ui.support.quote().ok)
	assert_false(ui.support.claim().ok)
	assert_false(world.tutorial.capture().support_used)
	bag.remove_from_slot(0, feed.get_stack_limit())
	bag.add(StarterSupport.SEED, 1)
	var cell: Vector2i = Vector2i(56, 20)
	world.farming.till(cell)
	assert_true(world.farming.plant(cell, bag, 0))
	assert_false(ui.support.quote().ok)
	assert_false(world.tutorial.capture().support_used)

func test_help_safe_area_targets_and_long_status_in_en_vi_at_densities_one_and_three() -> void:
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for density: int in [1, 3]:
			for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
				viewport.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
				viewport.set_meta(&"ui_point_scale", float(density))
				viewport.size = points * density
				viewport.size_2d_override = Vector2i(roundi(float(points.x) * 1080 / points.y), 1080)
				await wait_seconds(0.15)
				ui.open_help()
				for topic: int in [0, 3, 5]:
					ui.topics[topic].pressed.emit()
					ui._message = "Received one carrot seed. Move it to the hotbar, plant it, water it and sell the harvest."
					ui._refresh()
					await wait_process_frames(3)
					var safe: Rect2 = Rect2(Vector2(44, 0) * density, (Vector2(points) - Vector2(88, 21)) * density)
					var rect: Rect2 = viewport.get_stretch_transform() * ui.panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ui.panel.size)
					assert_true(safe.grow(1).encloses(rect), str(rect))
					for button: Button in [ui.close_button, ui.toggle_button, ui.skip_button]:
						rect = viewport.get_stretch_transform() * button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
						assert_true(safe.grow(1).encloses(rect))
						assert_gte(rect.size.y / density, 47.9)
				ui.close()
