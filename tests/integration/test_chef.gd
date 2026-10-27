extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const EGG: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
var viewport: SubViewport
var world: FarmWorld
var chef: ChefMerchant
var menu: CookingMenu

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(world)
	chef = world.get_node("Chef") as ChefMerchant
	menu = chef.menu as CookingMenu
	world.tool_upgrades.profile_ready = true
	world.player.global_position = chef.interaction_position() + Vector2(0, 20)
	await wait_process_frames(2)

func test_authored_chef_uses_existing_interaction_and_modal_lifecycle() -> void:
	assert_eq(world.player.shop_interaction.nearest_merchant(), chef)
	assert_true(world.player.shop_interaction.try_interact())
	assert_true(menu.is_open)
	assert_true(world.player.selection.is_menu_open())
	assert_eq(menu.recipe_buttons.size(), ChefCooking.RECIPES.size())
	assert_true(menu.cook_button.disabled)
	world.player.selection.inventory.add(EGG, 2)
	assert_false(menu.cook_button.disabled)
	menu._cook()
	assert_eq(world.cooking.queue.size(), 1)
	menu.close(false)
	assert_false(world.player.selection.is_menu_open())
	world.player.global_position += Vector2(100, 0)
	assert_false(chef.open_shop(world.player))

func test_save_migration_offline_restore_and_collect_into_inventory() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = world.farming.time_manager.now()
	var old: Dictionary = adapter.capture("chef_test", 1, now)
	old.version = 21
	old.erase("cooking")
	var checked: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(checked.ok)
	assert_eq(int(checked.snapshot.version), SaveSchema.VERSION)
	assert_false(old.has("cooking"))
	world.player.selection.inventory.add(EGG, 2)
	assert_eq(world.cooking.start("fried_egg", 2, world.player.selection.inventory, now), "")
	var saved: Dictionary = adapter.capture("chef_test", 1, now)
	assert_true(adapter.restore(saved, now + 14400.0).ok)
	assert_eq(world.cooking.ready.size(), 1)
	assert_eq(world.cooking.queue.size(), 1)
	assert_eq(world.cooking.collect(world.player.selection.inventory, now + 14400.0), 1)
	var latest: Dictionary = adapter.capture("chef_test", 2, now + 14400.0)
	assert_true(adapter.restore(latest, now + 14400.0).ok)
	assert_eq(world.cooking.ready.size(), 0)
	assert_eq(world.player.selection.inventory.count_item(&"fried_egg"), 1)
	latest.cooking.ready.append("unknown")
	assert_false(adapter.restore(latest, now + 14400.0).ok)
	assert_eq(world.player.selection.inventory.count_item(&"fried_egg"), 1)

func test_touch_panel_fits_landscape_and_uses_shared_quantity_controls() -> void:
	viewport.set_meta(&"touch_ui_override", true)
	viewport.size = Vector2i(844, 390)
	assert_true(chef.open_shop(world.player))
	await wait_process_frames(5)
	assert_true(Rect2(Vector2.ZERO, menu.root.size).encloses(menu.panel.get_rect()), "root=%s panel=%s min=%s" % [menu.root.size, menu.panel.get_rect(), menu.panel.get_combined_minimum_size()])
	assert_gte(menu.cook_button.size.y, 44.0)
	assert_gte(menu.collect_button.size.y, 44.0)
	var controls: TouchQuantityComponent = menu.quantity.get_node_or_null("TouchQuantityComponent") as TouchQuantityComponent
	if controls == null:
		for node: Node in menu.quantity.get_children():
			if node is TouchQuantityComponent:
				controls = node as TouchQuantityComponent
	assert_not_null(controls)
	assert_true(controls.increase.visible)

func test_cooking_snapshot_roundtrips_through_disk() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = world.farming.time_manager.now()
	world.player.selection.inventory.add(EGG, 2)
	world.cooking.start("fried_egg", 2, world.player.selection.inventory, now)
	var folder: String = "user://chef_tests_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(folder, adapter.catalog)
	assert_true(repository.write_profile("chef_test", adapter.capture("chef_test", 1, now), 0).ok)
	var loaded: Dictionary = repository.read_profile("chef_test")
	assert_true(loaded.ok)
	assert_true(adapter.restore(loaded.snapshot, now + 28800.0).ok)
	assert_eq(world.cooking.ready.size(), 2)
	assert_eq(world.player.selection.inventory.count_item(EGG.item_id), 0)
	DirAccess.remove_absolute(repository.path("chef_test"))
	DirAccess.remove_absolute(folder)

func test_overhead_progress_and_ready_count_without_opening_menu() -> void:
	var clock: Array[float] = [world.farming.time_manager.now()]
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	chef.refresh_cooking_status()
	assert_false(chef.cooking_status.visible)
	world.player.selection.inventory.add(EGG, 2)
	assert_eq(world.cooking.start("fried_egg", 2, world.player.selection.inventory, clock[0]), "")
	chef.refresh_cooking_status()
	assert_true(chef.cooking_status.visible)
	assert_almost_eq(chef.cooking_progress.value, 0.0, 0.01)
	clock[0] += 7200.0
	chef.refresh_cooking_status()
	assert_almost_eq(chef.cooking_progress.value, 50.0, 0.01)
	assert_true(chef.open_shop(world.player))
	chef.refresh_cooking_status()
	assert_false(chef.cooking_status.visible)
	menu.close(false)
	clock[0] += 14400.0
	chef.refresh_cooking_status()
	assert_eq(world.cooking.ready.size(), 1)
	assert_almost_eq(chef.cooking_progress.value, 50.0, 0.01)
	assert_true(chef.cooking_label.text.contains(tr("Ready: %d") % 1))
	clock[0] += 7200.0
	chef.refresh_cooking_status()
	assert_almost_eq(chef.cooking_progress.value, 100.0, 0.01)
	assert_true(chef.cooking_label.text.contains(tr("Ready: %d dishes") % 2))
	world.cooking.collect(world.player.selection.inventory, clock[0])
	chef.refresh_cooking_status()
	assert_false(chef.cooking_status.visible)
