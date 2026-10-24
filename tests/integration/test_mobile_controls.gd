extends GutTest

const FIXTURE = preload("res://tests/support/farming_fixture.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var viewport: SubViewport
var field: Node2D
var farm: FarmingController
var player: FarmPlayer
var controls: MobileControls

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(844, 390)
	viewport.set_meta(&"touch_layout", true)
	viewport.set_meta(&"ui_point_scale", 1.0)
	viewport.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
	add_child_autofree(viewport)
	field = FIXTURE.create_field()
	viewport.add_child(field)
	farm = field.get_node("FarmingController") as FarmingController
	player = PLAYER.instantiate() as FarmPlayer
	player.position = farm.farmland.map_to_local(Vector2i(20, 20))
	player.farming_actions.farming = farm
	field.add_child(player)
	controls = player.mobile_controls
	await wait_process_frames(5)
	await wait_physics_frames(2)
	player.camera.force_update_scroll()
	controls._process(0.0)

func after_each() -> void:
	Language.set_language("en")
	Input.action_release(&"move_left")

func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)

func _drag(index: int, point: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = point
	viewport.push_input(event, true)

func _tap(control: Control, index: int = 1) -> void:
	controls._process(0.0)
	_touch(index, _point(control), true)
	_touch(index, _point(control), false)

func test_joystick_moves_and_second_touch_uses_tool_without_waiting_for_release() -> void:
	var origin: Vector2 = player.position
	var joy: Vector2 = _point(controls.joystick)
	_touch(4, joy, true)
	_drag(4, joy + Vector2(120, 0))
	await wait_physics_frames(8)
	assert_gt(player.position.x, origin.x + 2)
	assert_gt(player.state.touch_direction.x, 0.9)
	_touch(8, _point(controls.tool_button), true)
	await wait_physics_frames(2)
	assert_eq(player.state.current_state, StateComponent.State.TOOL)
	assert_eq(controls.router.joystick_id, 4)
	_touch(8, _point(controls.tool_button), false)
	_touch(4, joy + Vector2(120, 0), false)
	await wait_seconds(0.9)
	assert_eq(player.state.touch_direction, Vector2.ZERO)
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	assert_false(player.state.navigation.has_focus)

func test_native_touch_tap_commits_on_release_and_pinch_never_moves_or_uses() -> void:
	var point: Vector2 = player.get_canvas_transform() * (player.position + Vector2(64, 0))
	_touch(0, point, true)
	assert_false(player.state.navigation.has_focus)
	_touch(0, point, false)
	assert_true(player.state.navigation.has_focus)
	player.state.navigation.cancel()
	var before: float = controls.zoom._target_zoom
	_touch(0, point, true)
	_touch(1, point + Vector2(100, 0), true)
	_drag(1, point + Vector2(200, 0))
	assert_gt(controls.zoom._target_zoom, before)
	_touch(1, point + Vector2(200, 0), false)
	_touch(0, point, false)
	assert_false(player.state.navigation.has_focus)
	assert_false(player.state._use_requested)
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	controls.zoom.pinch(1000)
	assert_lte(controls.zoom._target_zoom, controls.zoom.max_zoom)
	controls.zoom.pinch(0.0001)
	assert_gte(controls.zoom._target_zoom, controls.zoom._minimum_zoom())

func test_hotbar_and_modals_consume_touch_and_emulated_mouse_cannot_click_world() -> void:
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	var point: Vector2 = _point(hotbar.buttons[1])
	_touch(0, point, true)
	assert_eq(controls.router.fingers[0].role, &"ui")
	_touch(0, point, false)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	viewport.push_input(mouse, true)
	mouse.pressed = false
	viewport.push_input(mouse, true)
	assert_eq(player.selection.selected_index, 1)
	assert_false(player.state.navigation.has_focus)
	var joy: Vector2 = _point(controls.joystick)
	_touch(1, joy, true)
	_drag(1, joy + Vector2.RIGHT * 32)
	_touch(2, _point(hotbar.inventory_button), true)
	_touch(2, _point(hotbar.inventory_button), false)
	assert_true(player.selection.inventory_open, "Second finger opens Bag while joystick is held")
	assert_eq(player.state.touch_direction, Vector2.ZERO)
	assert_true(controls.router.fingers.is_empty())
	assert_false(controls.root.visible)
	_touch(1, joy, false)
	player.selection.set_inventory_open(false)
	assert_false(player.state.navigation.has_focus)
	mouse.position = Vector2(300, 180)
	mouse.pressed = true
	player.state._unhandled_input(mouse)
	assert_false(player.state.navigation.has_focus)

func test_rotation_focus_loss_cancel_and_mode_switch_release_all_input() -> void:
	var joy: Vector2 = _point(controls.joystick)
	_touch(0, joy, true)
	_drag(0, joy + Vector2.RIGHT * 32)
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(player.state.touch_direction, Vector2.ZERO)
	assert_true(controls.router.fingers.is_empty())
	controls._process(0)
	assert_false(controls.root.visible)
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	controls._process(0)
	assert_true(controls.root.visible)
	_touch(0, joy, true)
	_drag(0, joy + Vector2.RIGHT * 32)
	viewport.size = Vector2i(390, 844)
	await wait_process_frames(3)
	assert_eq(player.state.touch_direction, Vector2.ZERO)
	assert_false(controls.root.visible)
	viewport.size = Vector2i(844, 390)
	await wait_process_frames(3)
	assert_true(controls.root.visible)
	controls.cycle_mode() # On
	controls.cycle_mode() # Off
	controls._process(0)
	assert_false(controls.root.visible)
	controls.cycle_mode() # Auto
	controls._process(0)
	assert_true(controls.root.visible)
	_touch(0, _point(controls.joystick), true)
	_drag(0, _point(controls.joystick) + Vector2.RIGHT * 32)
	_touch(0, _point(controls.joystick), false, true)
	assert_eq(player.state.touch_direction, Vector2.ZERO)

func test_touch_farming_loop_uses_existing_impact_frames_and_interaction_resolver() -> void:
	var target: Vector2i = Vector2i(20, 21)
	FIXTURE.mark_cell(field, target)
	player.animation.face(Vector2.DOWN)
	player.selection.select_slot(0)
	_tap(controls.tool_button)
	assert_eq(farm.get_soil_state(target), FarmingController.Soil.UNTILLED)
	await wait_seconds(0.9)
	assert_eq(farm.get_soil_state(target), FarmingController.Soil.DRY)
	var seed: ItemDefinition = player.selection.inventory.get_slot_item(2)
	var seeds: int = player.selection.inventory.count_item(seed.item_id)
	player.selection.select_slot(2)
	_tap(controls.tool_button)
	await wait_seconds(0.9)
	assert_not_null(farm.get_crop(target))
	assert_eq(player.selection.inventory.count_item(seed.item_id), seeds - 1)
	player.selection.select_slot(1)
	_tap(controls.tool_button)
	await wait_seconds(0.9)
	assert_eq(farm.get_soil_state(target), FarmingController.Soil.WET)
	var crop: Crop = farm.get_crop(target)
	var now: float = farm.time_manager.now()
	crop.planted_at = now - 100
	crop.matures_at = now - 1
	crop.refresh(now)
	assert_true(crop.is_mature())
	player.interactions.refresh()
	_tap(controls.interact_button)
	await wait_seconds(0.9)
	assert_null(farm.get_crop(target))
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	assert_eq(player.selection.inventory.count_item(seed.crop.harvest_item.item_id), seed.crop.harvest_amount)

func test_context_button_opens_shop_and_modal_blocks_actions() -> void:
	var merchant: ShopMerchant = preload("res://scenes/characters/shop_merchant.tscn").instantiate() as ShopMerchant
	merchant.position = player.position + Vector2(0, 24)
	field.add_child(merchant)
	player.animation.face(Vector2.DOWN)
	await wait_physics_frames(2)
	player.interactions.refresh()
	_tap(controls.interact_button)
	assert_true(merchant.menu.is_open)
	assert_false(controls.root.visible)
	assert_true(controls.router.fingers.is_empty())
	player.state.request_use()
	assert_false(player.state._use_requested)
	merchant.menu.close(false)
	assert_false(player.state.navigation.has_focus)

func test_ui_swipe_scrolls_without_selecting_items_or_leaking_into_world() -> void:
	var bag: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	bag.open()
	await wait_process_frames(3)
	var scroll: ScrollContainer = bag.grid.get_parent().get_parent() as ScrollContainer
	var origin: Vector2 = _point(bag.buttons[1])
	var inspected: int = bag.inspected_index
	_touch(0, origin, true)
	assert_eq(controls.ui_scroll.fingers.size(), 1)
	_drag(0, origin - Vector2(0, 80))
	assert_gt(scroll.scroll_vertical, 0)
	_touch(0, origin - Vector2(0, 80), false)
	assert_eq(bag.inspected_index, inspected)
	assert_true(controls.ui_scroll.fingers.is_empty())
	assert_true(controls.router.fingers.is_empty())
	assert_false(player.state.navigation.has_focus)
	_touch(0, origin, true)
	controls.reset_input()
	assert_true(controls.ui_scroll.fingers.is_empty())
	bag.close()
	_touch(0, origin, false)
	assert_false(player.state.navigation.has_focus)

func test_session_touch_toggle_keeps_keyboard_available_and_changes_layout() -> void:
	viewport.set_meta(&"touch_layout", false)
	controls._process(0)
	assert_false(controls.root.visible)
	var bag: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	bag.open()
	bag.touch_mode_button.pressed.emit()
	bag.close()
	await wait_seconds(0.15)
	assert_true(controls.root.visible)
	assert_true(MobileLayout.is_touch(viewport))
	Input.action_press(&"move_left")
	await wait_physics_frames(3)
	assert_eq(player.animation.facing_vector, Vector2.LEFT)
	Input.action_release(&"move_left")
	bag.open()
	bag.touch_mode_button.pressed.emit()
	bag.close()
	await wait_seconds(0.15)
	assert_false(controls.root.visible)
	assert_false(MobileLayout.is_touch(viewport))

func test_controls_fit_safe_area_and_do_not_overlap_hotbar_at_high_dpi() -> void:
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	for density: int in [1, 3]:
		for size: Vector2i in [Vector2i(667, 375), Vector2i(844, 390), Vector2i(740, 360)]:
			viewport.set_meta(&"ui_point_scale", float(density))
			viewport.size = size * density
			viewport.size_2d_override = Vector2i(roundi(float(size.x) * 1080.0 / size.y), 1080)
			viewport.size_2d_override_stretch = true
			await wait_seconds(0.15)
			var dock: Rect2 = hotbar.slots.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, hotbar.slots.size)
			for language: String in ["en", "vi"]:
				Language.set_language(language)
				controls._process(0)
				var font: Font = controls.interact_button.get_theme_font(&"font")
				assert_lte(font.get_string_size(controls.interact_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, controls.interact_button.size.x - 8.0)
				assert_lte(hotbar.inventory_button.get_theme_font(&"font").get_string_size(hotbar.inventory_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, 58.0)
				for control: Control in [controls.joystick, controls.tool_button, controls.interact_button]:
					var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
					assert_false(rect.intersects(dock), str([size, density, language, control, rect, dock]))
					var physical: Rect2 = viewport.get_stretch_transform() * rect
					var safe: Rect2 = Rect2(Vector2(44, 0) * density, (Vector2(size) - Vector2(88, 21)) * density)
					assert_true(safe.grow(1).encloses(physical), str(physical))
					assert_gte(physical.size.x / density, 48.0)
					assert_gte(physical.size.y / density, 48.0)
