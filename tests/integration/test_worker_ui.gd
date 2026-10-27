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
	var board: WorkerBoard = world.get_node({"crop":"CropWorkers", "orchard":"OrchardWorkers", "ranch":"RanchWorkers"}[role]) as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0, 24)
	assert_true(board.open_shop(world.player))
	return board.menu as WorkerMenu

func test_crop_settings_pause_and_shared_supply_counts_use_real_models() -> void:
	var source: InventoryComponent = world.storages.inventory("farm_supply_storage")
	source.add(preload("res://items/seeds/carrot_seed.tres"), 12)
	source.add(preload("res://items/boosters/crop_fertilizer.tres"), 3)
	menu = _open("crop")
	assert_eq(menu.scene_file_path, "res://scenes/ui/workers.tscn")
	assert_false(menu.hire_button.disabled)
	menu._hire()
	assert_true(world.workers.record("crop").employed)
	assert_true(menu.hire_button.disabled)
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
	assert_ne(menu.preview, (world.workers.actors.crop as WorkerActor).sprite)

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

func test_other_roles_show_only_appropriate_controls_and_lock_assigned_pen() -> void:
	menu = _open("ranch")
	assert_true((menu.get_node("%ZoneBox") as VBoxContainer).visible)
	assert_false(menu.zones.disabled)
	assert_false((menu.get_node("%CropOptions") as VBoxContainer).visible)
	menu.zones.select(1)
	var pen_id: String = String(menu.zones.get_item_metadata(1))
	menu._hire()
	assert_eq(world.workers.record("ranch").zone, pen_id)
	assert_true(menu.zones.disabled)
	assert_false(menu.pause_crop_button.visible)
	menu.close(false)
	menu = _open("orchard")
	assert_false((menu.get_node("%ZoneBox") as VBoxContainer).visible)
	assert_false((menu.get_node("%CropOptions") as VBoxContainer).visible)
	assert_false(menu.collect_button.visible)
	menu._hire()
	assert_true(world.workers.record("orchard").employed)

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
		assert_true(Rect2(Vector2.ZERO, menu.root.size).grow(1).encloses(control.get_global_rect()))
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
	menu = _open("ranch")
	menu._hire()
	assert_false((menu.get_node("%LegacyBox") as VBoxContainer).visible)
	var bag: InventoryComponent = world.workers.bag_for("ranch")
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
