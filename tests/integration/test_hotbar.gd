extends GutTest

const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const Selection = preload("res://components/tool_selection_component.gd")
const Hotbar = preload("res://components/hotbar_ui.gd")
var viewport: SubViewport
var player: CharacterBody2D
var state: StateComponent
var selection: Selection
var hotbar: Hotbar

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	state = player.get_node("StateComponent")
	selection = player.get_node("ToolSelection")
	hotbar = player.get_node("Hotbar")
	await wait_physics_frames(3)

func _mouse(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	viewport.push_input(event, true)

func _click_slot(index: int) -> void:
	var center: Vector2 = hotbar.buttons[index].get_global_rect().get_center()
	_mouse(center, MOUSE_BUTTON_LEFT, true)
	_mouse(center, MOUSE_BUTTON_LEFT, false)

func _space(pressed: bool, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	viewport.push_input(event, true)

func test_hotbar_uses_ui_atlas_and_real_tool_icons() -> void:
	assert_eq(hotbar.buttons.size(), 6)
	assert_eq((hotbar.buttons[0].texture_normal as AtlasTexture).atlas.resource_path, "res://assets/Ui/buttons/Square Buttons 26x26.png")
	assert_not_null(hotbar.buttons[0].get_node("Icon").texture)
	assert_eq(hotbar.buttons[0].get_node("Icon").texture.region, Rect2(80, 0, 16, 16), "Use the actual hoe sprite, not the old mislabeled axe icon")
	assert_not_null(hotbar.buttons[1].get_node("Icon").texture)
	assert_eq(selection.inventory.slot(2).item.item_id, &"carrot_seed")
	assert_not_null(hotbar.buttons[2].get_node("Icon").texture)
	assert_true(hotbar.buttons[0].button_pressed)

func test_click_selects_tool_without_movement_or_using_it() -> void:
	var before: Vector2 = player.position
	_click_slot(1)
	await wait_physics_frames(2)
	assert_eq(selection.selected_index, 1)
	assert_eq(hotbar.selected_name.text, "Bình tưới")
	assert_true(hotbar.buttons[1].button_pressed)
	assert_false(hotbar.buttons[0].button_pressed)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(player.position, before)
	assert_false(state.movement.has_target)
	_click_slot(1)
	assert_true(hotbar.buttons[1].button_pressed, "Active slot remains selected after re-click")

func test_right_click_uses_selected_watering_can() -> void:
	_click_slot(1)
	_mouse(Vector2(400, 300), MOUSE_BUTTON_RIGHT, true)
	_mouse(Vector2(400, 300), MOUSE_BUTTON_RIGHT, false)
	await wait_physics_frames(2)
	assert_eq(state.current_state, StateComponent.State.WATER)
	assert_false(state.movement.has_target)

func test_space_after_hotbar_click_uses_selected_tool() -> void:
	_click_slot(1)
	_space(true)
	_space(false)
	await wait_physics_frames(2)
	assert_eq(state.current_state, StateComponent.State.WATER)

func test_number_keys_select_slots_without_using_tools() -> void:
	for code: int in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		viewport.push_input(event, true)
		event.pressed = false
		viewport.push_input(event, true)
		await wait_physics_frames(2)
		assert_eq(selection.selected_index, code - KEY_1)
		assert_true(hotbar.buttons[code - KEY_1].button_pressed)
		assert_eq(hotbar.buttons[code - KEY_1].get_node("Shortcut").text, str(code - KEY_1 + 1))
		assert_eq(state.current_state, StateComponent.State.IDLE)

func test_number_shortcut_then_space_uses_selected_tool() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_2
	event.pressed = true
	viewport.push_input(event, true)
	event.pressed = false
	viewport.push_input(event, true)
	_space(true)
	_space(false)
	await wait_physics_frames(2)
	assert_eq(state.current_state, StateComponent.State.WATER)

func test_empty_slot_does_not_use_any_tool() -> void:
	_click_slot(3)
	_space(true)
	_space(false)
	_mouse(Vector2(400, 300), MOUSE_BUTTON_RIGHT, true)
	await wait_physics_frames(2)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(hotbar.selected_name.text, "Ô trống")

func test_wheel_selects_and_wraps_slots() -> void:
	_mouse(Vector2(400, 300), MOUSE_BUTTON_WHEEL_DOWN, true)
	assert_eq(selection.selected_index, 1)
	_mouse(Vector2(400, 300), MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(Vector2(400, 300), MOUSE_BUTTON_WHEEL_UP, true)
	assert_eq(selection.selected_index, 5)
	assert_false(state.movement.has_target)

func test_wheel_over_hotbar_selects_tool() -> void:
	var center: Vector2 = hotbar.buttons[0].get_global_rect().get_center()
	_mouse(center, MOUSE_BUTTON_WHEEL_DOWN, true)
	assert_eq(selection.selected_index, 1)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_changing_selection_during_action_keeps_current_animation() -> void:
	_space(true)
	_space(false)
	await wait_physics_frames(2)
	_click_slot(1)
	assert_eq(state.current_state, StateComponent.State.TOOL)
	assert_eq(selection.get_selected_action(), &"water")
	assert_false(state.use_selected_tool(), "Cannot interrupt an action")
	await wait_seconds(0.9)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_true(state.use_selected_tool())
	assert_eq(state.current_state, StateComponent.State.WATER)

func test_busy_clicks_do_not_queue_another_action() -> void:
	_space(true)
	_space(false)
	await wait_physics_frames(2)
	_mouse(Vector2(400, 300), MOUSE_BUTTON_RIGHT, true)
	_space(true, true)
	_space(false)
	await wait_seconds(0.9)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_hotbar_is_centered_and_inside_viewport(size = use_parameters([
	Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(640, 360)
])) -> void:
	viewport.size = size
	await wait_physics_frames(3)
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
	for button: TextureButton in hotbar.buttons:
		assert_true(bounds.encloses(button.get_global_rect()))
	for index: int in range(hotbar.buttons.size() - 1):
		assert_false(hotbar.buttons[index].get_global_rect().intersects(hotbar.buttons[index + 1].get_global_rect()))
	assert_almost_eq(hotbar.slots.get_global_rect().get_center().x, float(size.x) / 2.0, 1.0)
	assert_true(bounds.encloses(hotbar.selected_name.get_global_rect()))
