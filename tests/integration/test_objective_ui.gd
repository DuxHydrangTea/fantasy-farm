extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var ui: ObjectiveUI

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	await wait_physics_frames(2)
	ui = world.objective_ui

func after_each() -> void:
	Language.set_language("en")

func test_modal_exclusion_claim_once_and_load_closes_page() -> void:
	ui.open()
	assert_true(ui.overlay.visible)
	assert_true(world.player.selection.is_menu_open())
	world.player.selection.set_inventory_open(true)
	world.player.selection.set_shop_open(true)
	assert_false(world.player.selection.inventory_open)
	assert_false(world.player.selection.shop_open)
	assert_true(ui.claim_button.disabled)
	world.objectives.progress.state_query = func(_condition: StringName) -> int: return 1
	world.objectives.progress.refresh_state()
	assert_false(ui.claim_button.disabled)
	var before: int = world.player.wallet.balance
	ui.claim_button.pressed.emit()
	ui.claim_button.pressed.emit()
	assert_eq(world.player.wallet.balance, before + ObjectiveProgress.DEFAULT_CATALOG.steps[0].reward_coins)
	assert_true(ui.claim_button.disabled)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("ui_test", 1, world.farming.time_manager.now())
	assert_true(adapter.restore(saved, world.farming.time_manager.now()).ok)
	assert_false(ui.overlay.visible)
	assert_false(world.player.selection.is_menu_open())
	assert_eq(ui.notice.text, "")

func test_tracking_collapse_language_and_menu_exclusion() -> void:
	ui.inspect(8)
	ui.track_button.pressed.emit()
	assert_eq(world.objectives.progress.tracked_index(), 8)
	assert_true(ui.claim_button.disabled)
	ui.collapse_button.pressed.emit()
	assert_true(world.objectives.progress.hud_collapsed)
	Language.set_language("vi")
	await wait_process_frames(2)
	assert_eq(ui.hud_button.text, "Mục tiêu")
	assert_eq(ui.claim_button.text, "Nhận thưởng")
	world.player.selection.set_inventory_open(true)
	ui.open()
	assert_false(ui.overlay.visible)
	assert_false(ui.hud.visible)
	world.player.selection.set_inventory_open(false)
	assert_true(ui.hud.visible)

func test_v12_migrates_preferences_and_preserves_progress() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("ui_test", 1, world.farming.time_manager.now())
	saved.version = 12
	saved.objectives.erase("tracked_id")
	saved.objectives.erase("hud_collapsed")
	var result: Dictionary = SaveSchema.validate(saved, SaveCatalog.new())
	assert_true(result.ok)
	if result.ok:
		assert_eq(result.snapshot.objectives.tracked_id, "")
		assert_false(result.snapshot.objectives.hud_collapsed)

func test_preferences_and_ready_state_restore_without_completion_replay() -> void:
	world.objectives.progress.state_query = func(_condition: StringName) -> int: return 1
	world.objectives.progress.refresh_state()
	assert_false(ui.claim_button.disabled)
	world.objectives.progress.track("first_expansion")
	world.objectives.progress.set_collapsed(true)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("ui_test", 1, world.farming.time_manager.now())
	world.objectives.progress.track("first_soil")
	world.objectives.progress.set_collapsed(false)
	assert_true(adapter.restore(saved, world.farming.time_manager.now()).ok)
	assert_eq(world.objectives.progress.tracked_index(), 8)
	assert_true(world.objectives.progress.hud_collapsed)
	assert_eq(ui.notice.text, "")
	assert_false(ui.overlay.visible)

func test_phone_safe_area_and_targets_in_both_languages_and_densities() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.set_meta(&"touch_layout", true)
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(844, 390)
	viewport.size_2d_override = Vector2i(2337, 1080)
	add_child_autofree(viewport)
	var farm: FarmWorld = WORLD.instantiate() as FarmWorld
	for child: Node in farm.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(farm)
	var page: ObjectiveUI = farm.objective_ui
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for density: int in [1, 3]:
			for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
				viewport.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
				viewport.set_meta(&"ui_point_scale", float(density))
				viewport.size = points * density
				viewport.size_2d_override = Vector2i(roundi(float(points.x) * 1080 / points.y), 1080)
				await wait_seconds(0.15)
				page.open()
				await wait_process_frames(3)
				var safe: Rect2 = Rect2(Vector2(44, 0) * density, (Vector2(points) - Vector2(88, 21)) * density)
				var transform: Transform2D = viewport.get_stretch_transform() * page.panel.get_global_transform_with_canvas()
				assert_true(safe.grow(1).encloses(transform * Rect2(Vector2.ZERO, page.panel.size)))
				for button: Button in [page.claim_button, page.track_button, page.close_button, page.rows[0]]:
					var pixels: Rect2 = viewport.get_stretch_transform() * button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
					assert_gte(pixels.size.y / density, 47.9)
					assert_true(safe.grow(1).encloses(pixels))
				page.close()
