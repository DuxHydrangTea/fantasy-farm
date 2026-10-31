extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var viewport: SubViewport
var menu: WorkerMenu
var previous_clock: Callable
var previous_floor: float

func before_each() -> void:
	previous_clock = TimeManager.clock_source
	previous_floor = TimeManager._last_timestamp
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(100000)
	var timestamp: float = TimeManager.now()
	TimeManager.clock_source = func() -> float: return timestamp
	world.trees.reset()
	for index: int in range(10):
		world.trees.create_tree(Vector2i(12 + index * 3, 61), world.trees.definitions[&"apple"], timestamp)
	await wait_process_frames(2)

func after_each() -> void:
	TimeManager.clock_source = previous_clock
	TimeManager._last_timestamp = previous_floor
	Language.set_language("en")

func _open(role: String) -> WorkerMenu:
	var board: WorkerBoard = world.get_node("CropWorkers") as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0, 24)
	assert_true(board.open_shop(world.player))
	return board.menu as WorkerMenu

func test_unified_menu_shows_one_team_with_all_controls() -> void:
	menu = _open("crop")
	assert_null(world.get_node_or_null("OrchardWorkers"), "Orchard board removed")
	assert_null(world.get_node_or_null("RanchWorkers"), "Ranch board removed")
	assert_true((menu.get_node("%CropOptions") as VBoxContainer).visible)
	assert_null(menu.get_node_or_null("%ZoneBox"), "Zone box removed from the scene")
	menu._hire()
	assert_true(world.workers.record("crop").employed)
	var heading: Label = menu.get_node("%Heading") as Label
	assert_true("15" in heading.text, "Heading shows the 15 cap: " + heading.text)

func test_crop_settings_pause_and_shared_supply_counts_use_real_models() -> void:
	var source: InventoryComponent = world.storages.inventory("farm_supply_storage")
	source.add(preload("res://items/seeds/carrot_seed.tres"), 12)
	source.add(preload("res://items/boosters/crop_fertilizer.tres"), 3)
	menu = _open("crop")
	assert_eq(menu.scene_file_path, "res://scenes/ui/workers.tscn")
	assert_false(menu.hire_button.disabled)
	menu._hire()
	assert_true(world.workers.record("crop").employed)
	assert_false(menu.hire_button.disabled)
	assert_true(menu.auto_plant_button.button_pressed)
	menu._toggle_auto_plant()
	assert_false(world.workers.crop_automation.auto_plant)
	menu._toggle_auto_fertilize()
	assert_true(world.workers.crop_automation.auto_fertilize)
	menu._toggle_crop_pause()
	assert_true(world.workers.crop_automation.paused)
	assert_true(world.workers.record("crop").employed)
	assert_string_contains((menu.get_node("%Supplies") as Label).text, "12")
	assert_string_contains((menu.get_node("%Supplies") as Label).text, "3")
	assert_ne(menu.preview, (world.workers.actor_for("crop")).sprite)

func test_dismissal_cancel_and_paid_rehire_preserve_once_only_trial() -> void:
	menu = _open("crop")
	menu._hire()
	var balance: int = world.player.wallet.balance
	menu._dismiss()
	assert_true(menu.confirmation.visible)
	assert_true(world.workers.record("crop").employed)
	menu._cancel_dismiss()
	assert_true(world.workers.record("crop").employed)
	menu._dismiss()
	menu._dismiss()
	assert_false(world.workers.record("crop").employed)
	assert_eq(world.player.wallet.balance, balance)
	assert_false(menu.confirmation.visible)
	menu._hire()
	assert_eq(world.player.wallet.balance, balance - int(WorkerRole.WAGES.crop))
	menu._dismiss()
	menu.close(false)
	assert_false(menu._confirm)
	assert_false(world.player.selection.shop_open)

func test_locked_hiring_and_insufficient_rehire_funds_disable_action() -> void:
	world.land.state.restore_columns(4, 4)
	menu = _open("crop")
	assert_true(menu.hire_button.disabled)
	assert_true((menu.get_node("%Unlock") as Label).visible)
	world.land.state.restore_columns(12, 4)
	menu._refresh()
	assert_false(menu.hire_button.disabled)
	menu._hire()
	menu._dismiss()
	menu._dismiss()
	world.player.wallet.set_balance(0)
	assert_true(menu.hire_button.disabled)
	assert_true(world.workers.trial_used.has("crop"))

func test_compact_and_confirmation_keep_actions_in_safe_area_and_restore_columns() -> void:
	menu = _open("crop")
	menu._hire()
	Language.set_language("vi")
	viewport.set_meta(&"touch_ui_override", true)
	viewport.size = Vector2i(667, 375)
	await wait_process_frames(8)
	assert_eq(menu.get_node("%SupplyPanel").get_parent(), menu.get_node("%WorkContent"))
	for control: Control in [menu.panel, menu.close_button, menu.pause_crop_button, menu.dismiss_button]:
		assert_true(Rect2(Vector2.ZERO, menu.root.size).grow(1).encloses(control.get_global_rect()), "%s: %s within %s" % [control.name, control.get_global_rect(), menu.root.size])
	menu._dismiss()
	await wait_process_frames(4)
	assert_true(Rect2(Vector2.ZERO, menu.root.size).grow(1).encloses(menu.confirm_button.get_global_rect()))
	assert_gte(menu.confirm_button.size.y, 48.0)
	menu._cancel_dismiss()
	viewport.set_meta(&"touch_ui_override", false)
	viewport.size = Vector2i(1280, 720)
	await wait_process_frames(8)
	assert_eq(menu.get_node("%SupplyPanel").get_parent(), menu.get_node("%Main"))

func test_recovery_actions_only_appear_for_remaining_old_basket_contents() -> void:
	menu = _open("crop")
	menu._hire()
	assert_false((menu.get_node("%LegacyBox") as VBoxContainer).visible)
	var bag: InventoryComponent = world.workers.bag_for("crop")
	var feed: ItemDefinition = preload("res://items/feeds/poultry_feed.tres")
	bag.add(feed, 3)
	menu._refresh()
	assert_true(menu.withdraw_button.visible)
	assert_false(menu.withdraw_button.disabled)
	assert_false(menu.collect_button.visible)
	bag.remove(feed.item_id, 3)
	menu._refresh()
	assert_false((menu.get_node("%LegacyBox") as VBoxContainer).visible)
	assert_true(menu.withdraw_button.disabled)

func test_crop_team_selector_hires_to_cap_and_dismisses_only_selected_worker() -> void:
	menu = _open("crop")
	for index: int in range(15):
		assert_false(menu.hire_button.disabled)
		menu._hire()
	assert_true(menu.hire_button.disabled)
	assert_eq(menu.team_list.get_child_count(), 15)
	assert_eq(world.workers.records_for("crop", true).size(), 15)
	assert_string_contains(menu.team_summary.text, "42,000")
	menu._select_worker(2)
	var selected_id: String = menu.selected_worker_id
	var other_id: String = String(menu.team_list.get_child(0).get_meta("worker_id"))
	menu._dismiss()
	menu._dismiss()
	assert_false(world.workers.record_for(selected_id).employed)
	assert_true(world.workers.record_for(other_id).employed)
	assert_false(menu.hire_button.disabled)
	menu._hire()
	assert_eq(menu.selected_worker_id, selected_id)
	assert_eq(menu.team_list.get_child_count(), 15)

func test_interacting_with_worker_opens_its_own_selection_and_five_fit_compact_view() -> void:
	menu = _open("crop")
	for index: int in range(5):
		menu._hire()
	var id: String = menu.selected_worker_id
	menu.close(false)
	var actor: WorkerActor = world.workers.actor_for(id)
	var access: WorkerBoard
	for child: Node in actor.get_children():
		if child is WorkerBoard:
			access = child as WorkerBoard
	assert_not_null(access)
	world.player.global_position = actor.global_position + Vector2(0, 24)
	assert_true(access.open_shop(world.player))
	menu = access.menu as WorkerMenu
	assert_eq(menu.selected_worker_id, id)
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		viewport.set_meta(&"touch_ui_override", true)
		viewport.size = Vector2i(667, 375)
		await wait_process_frames(8)
		assert_true(Rect2(Vector2.ZERO, menu.root.size).grow(1).encloses(menu.panel.get_global_rect()))
		assert_true(Rect2(Vector2.ZERO, menu.root.size).grow(1).encloses(menu.hire_button.get_global_rect()))

func test_crop_roster_displays_five_rows_and_selection_updates_details_without_rebuilding() -> void:
	menu = _open("crop")
	for index: int in range(5):
		menu._hire()
	await wait_process_frames(5)
	assert_eq(menu.team_list.get_child_count(), 5)
	var roster_bounds: Rect2 = (menu.get_node("%OverviewScroll") as ScrollContainer).get_global_rect().grow(1)
	for child: Button in menu.team_list.get_children():
		assert_true(child.is_visible_in_tree())
		assert_true(roster_bounds.encloses(child.get_global_rect()), "All five rows fit the desktop roster: " + child.name)
	var button: Button = menu.team_list.get_child(1) as Button
	var id: String = String(button.get_meta("worker_id"))
	button.pressed.emit()
	assert_eq(menu.selected_worker_id, id)
	assert_true(button.button_pressed)
	assert_string_contains((menu.get_node("%WorkerName") as Label).text, "#2")
	assert_eq((menu.get_node("%WorkerName") as Label).get_parent(), menu.get_node("%WorkContent"))
	assert_eq((menu.get_node("%Employment") as Label).get_parent(), menu.get_node("%WorkContent"))
	assert_false(menu.portrait.visible)
	menu._refresh()
	assert_eq(menu.team_list.get_child(1), button, "Periodic refresh preserves focusable rows")
	assert_true(button.button_pressed)
	assert_false((menu.team_list.get_child(0) as Button).button_pressed)

func test_crop_roster_empty_hint_and_other_role_portrait_visibility() -> void:
	menu = _open("crop")
	assert_true((menu.get_node("%TeamEmpty") as Label).is_visible_in_tree())
	assert_eq(menu.team_list.get_child_count(), 0)
	menu._hire()
	assert_false((menu.get_node("%TeamEmpty") as Label).visible)
	menu.close(false)
	menu = _open("crop")
	assert_true(menu.team_list.is_visible_in_tree())
	assert_false(menu.portrait.visible, "The hired worker is auto-selected and hides the preview")
	assert_eq((menu.get_node("%WorkerName") as Label).get_parent(), menu.get_node("%WorkContent"))


func test_restored_slide_and_stable_worker_buttons() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.set_physics_process(false)
	menu = _open("crop")
	assert_eq(menu.offset.y, menu.get_viewport().get_visible_rect().size.y)
	assert_eq((menu.root.get_node("Dim") as ColorRect).color.a, 0.0)
	await wait_seconds(0.4)
	assert_eq(menu.offset.y, 0.0)
	menu._hire()
	world.workers.busy = true
	world.storages.busy = true
	world.storages.changed.emit("produce_warehouse")
	world.workers.changed.emit()
	for button: Button in [menu.hire_button, menu.dismiss_button, menu.pause_crop_button]:
		assert_false(button.disabled)
	world.workers.busy = false
	world.storages.busy = false
	await wait_process_frames(2)
	menu.close()
	assert_true(menu.is_open)
	await wait_seconds(0.35)
	assert_false(menu.is_open)
	assert_false(menu.root.visible)
	assert_eq(menu.offset.y, 0.0)
	assert_eq(ProjectSettings.get_setting("display/window/size/window_width_override"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/window_height_override"), 1080)
