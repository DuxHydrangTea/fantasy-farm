extends GutTest

const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"farmer_tool", &"farmer_water"]
var player: CharacterBody2D
var state: StateComponent
var sprite: AnimatedSprite2D
var camera: Camera2D
var viewport: SubViewport

func before_each() -> void:
	_release_input()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	state = player.get_node("StateComponent")
	sprite = player.get_node("AnimatedSprite2D")
	camera = player.get_node("Camera2D")
	await wait_physics_frames(2)

func after_each() -> void:
	_release_input()

func _release_input() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)
	for code: int in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_1, KEY_2]:
		_send_key(code, false)

func _send_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	if code == KEY_SPACE:
		viewport.push_input(event, true)
	else:
		Input.parse_input_event(event)

func test_physical_movement_keys(case = use_parameters([
	[KEY_LEFT, Vector2.LEFT], [KEY_RIGHT, Vector2.RIGHT],
	[KEY_UP, Vector2.UP], [KEY_DOWN, Vector2.DOWN],
	[KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT],
	[KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]
])) -> void:
	var start: Vector2 = player.position
	var direction: Vector2 = case[1]
	_send_key(case[0], true)
	await wait_physics_frames(12)
	var displacement: Vector2 = player.position - start
	assert_gt(displacement.dot(direction), 0.0, "Key moves in expected direction")
	assert_almost_eq(displacement.cross(direction), 0.0, 0.01)
	assert_eq(state.current_state, StateComponent.State.WALK)
	if direction.x != 0.0:
		assert_eq(sprite.flip_h, direction.x < 0.0)
	_send_key(case[0], false)
	await wait_physics_frames(15)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(player.velocity, Vector2.ZERO)

func test_selected_tool_locks_then_resumes_movement(case = use_parameters([
	[0, StateComponent.State.TOOL, &"tool_down"],
	[1, StateComponent.State.WATER, &"water_down"]
])) -> void:
	player.get_node("ToolSelection").select_slot(case[0])
	_send_key(KEY_SPACE, true)
	await wait_physics_frames(2)
	_send_key(KEY_SPACE, false)
	assert_eq(state.current_state, case[1])
	assert_eq(sprite.animation, case[2])
	var locked_position: Vector2 = player.position
	_send_key(KEY_RIGHT, true)
	await wait_physics_frames(4)
	assert_eq(player.position, locked_position)
	assert_eq(player.velocity, Vector2.ZERO)
	await wait_seconds(1.5)
	assert_eq(state.current_state, StateComponent.State.WALK)
	assert_gt(player.position.x, locked_position.x)
	assert_false(sprite.flip_h)

func test_camera_follows_player() -> void:
	assert_eq(viewport.get_camera_2d(), camera)
	assert_eq(camera.zoom, Vector2(3, 3))
	player.position = Vector2(1200, 650)
	await wait_seconds(0.8)
	var center: Vector2 = camera.get_screen_center_position()
	assert_almost_eq(center.x, player.position.x, 3.0)
	assert_almost_eq(center.y, player.position.y, 3.0)

func test_camera_keeps_view_inside_map(position = use_parameters([
	Vector2(-500, -500), Vector2(2400, 1600)
])) -> void:
	player.position = position
	camera.reset_smoothing()
	camera.force_update_scroll()
	await wait_physics_frames(2)
	var center: Vector2 = camera.get_screen_center_position()
	var half_view: Vector2 = Vector2(viewport.size) / camera.zoom / 2.0
	assert_gte(center.x - half_view.x, -0.01)
	assert_gte(center.y - half_view.y, -0.01)
	assert_lte(center.x + half_view.x, 1920.01)
	assert_lte(center.y + half_view.y, 1080.01)

func _click_world(world_position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = player.get_canvas_transform() * world_position
	click.global_position = click.position
	click.button_index = button
	click.pressed = true
	viewport.push_input(click, true)
	click.pressed = false
	viewport.push_input(click, true)

func test_left_click_reaches_world_target_and_stops() -> void:
	var target: Vector2 = player.global_position + Vector2(60, -30)
	_click_world(target)
	assert_true(state.movement.has_target)
	assert_almost_eq(state.movement.target_position.x, target.x, 0.01)
	assert_almost_eq(state.movement.target_position.y, target.y, 0.01)
	await wait_physics_frames(10)
	assert_eq(state.current_state, StateComponent.State.WALK)
	await wait_seconds(0.9)
	assert_lte(player.global_position.distance_to(target), state.movement.arrival_distance)
	assert_false(state.movement.has_target)
	assert_eq(player.velocity, Vector2.ZERO)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	var arrived: Vector2 = player.position
	await wait_physics_frames(10)
	assert_eq(player.position, arrived, "No oscillation after arrival")

func test_new_click_replaces_destination() -> void:
	_click_world(player.global_position + Vector2(100, 0))
	await wait_physics_frames(3)
	var replacement: Vector2 = player.global_position + Vector2(-50, 0)
	_click_world(replacement)
	await wait_seconds(0.8)
	assert_lte(player.global_position.distance_to(replacement), state.movement.arrival_distance)
	assert_true(sprite.flip_h)

func test_keyboard_cancels_click_destination() -> void:
	_click_world(player.global_position + Vector2(100, 0))
	await wait_physics_frames(5)
	_send_key(KEY_LEFT, true)
	await wait_physics_frames(10)
	assert_false(state.movement.has_target)
	assert_lt(player.velocity.x, 0.0)
	_send_key(KEY_LEFT, false)
	await wait_physics_frames(15)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_false(state.movement.has_target, "Does not resume stale mouse target")

func test_action_cancels_destination_and_ignores_clicks() -> void:
	_click_world(player.global_position + Vector2(100, 0))
	await wait_physics_frames(5)
	_send_key(KEY_SPACE, true)
	await wait_physics_frames(2)
	_send_key(KEY_SPACE, false)
	assert_eq(state.current_state, StateComponent.State.TOOL)
	assert_false(state.movement.has_target)
	var locked: Vector2 = player.position
	_click_world(locked + Vector2(0, 100))
	assert_false(state.movement.has_target)
	await wait_seconds(1.5)
	assert_eq(player.position, locked)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_right_click_uses_tool_without_moving() -> void:
	_click_world(player.position + Vector2(100, 0), MOUSE_BUTTON_RIGHT)
	await wait_physics_frames(5)
	assert_false(state.movement.has_target)
	assert_eq(state.current_state, StateComponent.State.TOOL)

func test_ui_consumes_click_before_movement() -> void:
	var overlay: Control = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.size = Vector2(viewport.size)
	viewport.add_child(overlay)
	await wait_physics_frames(2)
	_click_world(player.position + Vector2(50, 0))
	await wait_physics_frames(2)
	assert_false(state.movement.has_target, "UI clicks must not move the player")

func test_blocked_mouse_movement_stops_at_collider() -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(10, 100)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = player.position + Vector2(30, 0)
	viewport.add_child(wall)
	await wait_physics_frames(2)
	_click_world(player.position + Vector2(80, 0))
	await wait_seconds(1.0)
	assert_lt(player.position.x, wall.position.x)
	assert_false(state.movement.has_target)
	assert_eq(state.current_state, StateComponent.State.IDLE)
