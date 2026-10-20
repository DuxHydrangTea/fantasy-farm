extends GutTest

const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"farmer_tool", &"farmer_water"]
var player: CharacterBody2D
var state: StateComponent
var sprite: AnimatedSprite2D
var camera: Camera2D
var viewport: SubViewport
var navigation: PlayerNavigationComponent

func test_navigation_reuses_grid_and_bounds_physics_queries_per_frame() -> void:
	state.set_physics_process(false)
	navigation.set_physics_process(false)
	navigation.invalidate_cache()
	var target: Vector2 = player.position + Vector2(160, -80)
	navigation.request_focus(target)
	var before: int = navigation.total_physics_queries
	for index: int in range(64):
		var frame_before: int = navigation.total_physics_queries
		navigation.move(1.0 / 60.0)
		assert_lte(navigation.total_physics_queries - frame_before, navigation.sampling_budget + 128)
		if not navigation._planning:
			break
		await wait_physics_frames(1)
	assert_false(navigation._planning)
	assert_true(navigation.is_navigating)
	var cold_queries: int = navigation.total_physics_queries - before
	var original_grid: AStarGrid2D = navigation._grid
	navigation.request_focus(target)
	before = navigation.total_physics_queries
	navigation.move(1.0 / 60.0)
	assert_eq(navigation._grid, original_grid)
	assert_lt(navigation.total_physics_queries - before, cold_queries)
	assert_false(navigation._planning)

func test_harvest_and_mouse_tool_actions_can_be_remapped() -> void:
	var originals: Dictionary = {}
	for action: StringName in [&"harvest", &"use_item"]:
		originals[action] = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
	var harvest: InputEventKey = InputEventKey.new()
	harvest.physical_keycode = KEY_F
	InputMap.action_add_event(&"harvest", harvest)
	var use: InputEventKey = InputEventKey.new()
	use.physical_keycode = KEY_R
	InputMap.action_add_event(&"use_item", use)
	var old: InputEventKey = InputEventKey.new()
	old.physical_keycode = KEY_E
	old.pressed = true
	state._unhandled_input(old)
	assert_false(state._harvest_requested)
	harvest.pressed = true
	state._unhandled_input(harvest)
	assert_true(state._harvest_requested)
	var old_mouse: InputEventMouseButton = InputEventMouseButton.new()
	old_mouse.button_index = MOUSE_BUTTON_RIGHT
	old_mouse.pressed = true
	state._unhandled_input(old_mouse)
	assert_false(state._use_requested)
	use.pressed = true
	state._unhandled_input(use)
	assert_true(state._use_requested)
	state._use_requested = false
	state._harvest_requested = false
	for action: StringName in originals:
		InputMap.action_erase_events(action)
		for event: InputEvent in originals[action]:
			InputMap.action_add_event(action, event)

func before_each() -> void:
	_release_input()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	await get_tree().process_frame
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	state = player.get_node("StateComponent")
	sprite = player.get_node("AnimatedSprite2D")
	camera = player.get_node("Camera2D")
	navigation = state.navigation
	camera.make_current()
	await wait_physics_frames(2)
	await get_tree().process_frame
	await get_tree().process_frame
	camera.force_update_scroll()

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

func test_full_hd_camera_uses_requested_zoom_and_follows_within_map_limits() -> void:
	assert_eq(viewport.get_camera_2d(), camera)
	assert_eq(camera.zoom, Vector2(1.2, 1.2))
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1920)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1080)
	player.position = Vector2(1200, 650)
	await wait_seconds(0.8)
	var center: Vector2 = camera.get_screen_center_position()
	assert_almost_eq(center.x, 1120.0, 3.0)
	assert_almost_eq(center.y, 630.0, 3.0)

func test_camera_keeps_view_inside_map(position = use_parameters([
	Vector2(-500, -500), Vector2(2400, 1600)
])) -> void:
	player.position = position
	await get_tree().process_frame
	await get_tree().process_frame
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

func _wheel(button: MouseButton, pressed: bool = true) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = Vector2(400, 300)
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	viewport.push_input(event, true)

func test_wheel_zoom_is_smooth_and_accumulates_fast_steps() -> void:
	var initial_zoom: Vector2 = camera.zoom
	for step: int in range(3):
		_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_eq(camera.zoom, initial_zoom, "Zoom eases towards its target")
	await wait_seconds(0.7)
	assert_almost_eq(camera.zoom.x, 1.2 * pow(1.15, 3), 0.002)
	assert_eq(camera.zoom.x, camera.zoom.y)
	for step: int in range(3):
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await wait_seconds(0.7)
	assert_almost_eq(camera.zoom.x, initial_zoom.x, 0.002)

func test_wheel_zoom_clamps_and_keeps_map_inside_view() -> void:
	for step: int in range(40):
		_wheel(MOUSE_BUTTON_WHEEL_UP)
	await wait_seconds(0.8)
	assert_almost_eq(camera.zoom.x, 3.0, 0.002)
	for step: int in range(60):
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await wait_seconds(0.8)
	assert_almost_eq(camera.zoom.x, 1.0, 0.002)
	camera.reset_smoothing()
	camera.force_update_scroll()
	await wait_physics_frames(2)
	var center: Vector2 = camera.get_screen_center_position()
	var half_view: Vector2 = Vector2(viewport.size) / camera.zoom / 2.0
	assert_gte(center.x - half_view.x, -0.01)
	assert_gte(center.y - half_view.y, -0.01)
	assert_lte(center.x + half_view.x, 1920.01)
	assert_lte(center.y + half_view.y, 1080.01)

func test_zoom_minimum_adapts_to_viewport_resize() -> void:
	viewport.size = Vector2i(3840, 2160)
	await wait_physics_frames(3)
	assert_gte(camera.zoom.x, 2.0, "Larger viewport must not expose outside the map")
	for step: int in range(20):
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await wait_seconds(0.7)
	assert_almost_eq(camera.zoom.x, 2.0, 0.002)

func test_inventory_blocks_wheel_zoom() -> void:
	var inventory_ui: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	inventory_ui.open()
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await wait_seconds(0.6)
	assert_eq(camera.zoom, Vector2(1.2, 1.2))
	inventory_ui.close()
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await wait_seconds(0.6)
	assert_gt(camera.zoom.x, 1.2)

func test_ui_consumed_wheel_does_not_zoom_world() -> void:
	var overlay: Control = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.mouse_force_pass_scroll_events = false
	overlay.size = Vector2(viewport.size)
	viewport.add_child(overlay)
	await wait_physics_frames(2)
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await wait_seconds(0.6)
	assert_eq(camera.zoom, Vector2(1.2, 1.2))

func test_wheel_release_is_ignored() -> void:
	_wheel(MOUSE_BUTTON_WHEEL_UP, false)
	await wait_seconds(0.6)
	assert_eq(camera.zoom, Vector2(1.2, 1.2))

func test_click_focus_stays_correct_after_zoom() -> void:
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await wait_seconds(0.7)
	await wait_physics_frames(2)
	var target: Vector2 = player.global_position + Vector2(60, -30)
	_click_world(target)
	assert_true(navigation.has_focus)
	assert_almost_eq(navigation.focus_position.x, target.x, 0.01)
	assert_almost_eq(navigation.focus_position.y, target.y, 0.01)
	await wait_seconds(0.9)
	assert_lte(player.global_position.distance_to(target), navigation.interaction_distance + state.movement.arrival_distance)
	assert_false(navigation.is_navigating)

func test_left_click_approaches_focus_then_faces_it_without_stepping_on_it() -> void:
	var target: Vector2 = player.global_position + Vector2(60, -30)
	_click_world(target)
	assert_true(navigation.has_focus)
	assert_almost_eq(navigation.focus_position.x, target.x, 0.01)
	assert_almost_eq(navigation.focus_position.y, target.y, 0.01)
	await wait_physics_frames(10)
	assert_eq(state.current_state, StateComponent.State.WALK)
	await wait_seconds(0.9)
	assert_lte(player.global_position.distance_to(target), navigation.interaction_distance + state.movement.arrival_distance)
	assert_gt(player.global_position.distance_to(target), state.movement.arrival_distance)
	var facing: Vector2 = (player as FarmPlayer).animation.facing_vector
	assert_gt(facing.dot(player.global_position.direction_to(target)), 0.4)
	assert_false(navigation.is_navigating)
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
	assert_lte(player.global_position.distance_to(replacement), navigation.interaction_distance + state.movement.arrival_distance)
	assert_almost_eq(navigation.focus_position.x, replacement.x, 0.001)
	assert_almost_eq(navigation.focus_position.y, replacement.y, 0.001)
	assert_true(sprite.flip_h)

func test_keyboard_cancels_click_destination() -> void:
	_click_world(player.global_position + Vector2(100, 0))
	await wait_physics_frames(5)
	_send_key(KEY_LEFT, true)
	await wait_physics_frames(10)
	assert_false(state.movement.has_target)
	assert_false(navigation.has_focus)
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
	assert_false(navigation.has_focus)
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
	assert_false(navigation.has_focus)

func _wall(offset: Vector2, wall_size: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = wall_size
	collision.shape = shape
	wall.add_child(collision)
	wall.position = player.position + offset
	viewport.add_child(wall)
	return wall

func test_click_focus_finds_a_path_around_collision() -> void:
	var wall: StaticBody2D = _wall(Vector2(30, 0), Vector2(10, 100))
	await wait_physics_frames(2)
	var start: Vector2 = player.position
	var focus: Vector2 = start + Vector2(96, 0)
	_click_world(focus)
	var detour: float = 0.0
	for frame: int in range(180):
		await wait_physics_frames(1)
		detour = maxf(detour, absf(player.position.y - start.y))
	assert_gt(detour, 45.0, "Must go around the wall")
	assert_gt(player.position.x, wall.position.x)
	assert_lte(player.position.distance_to(focus), navigation.interaction_distance + state.movement.arrival_distance)
	assert_false(state.movement.has_target)
	assert_false(navigation.is_navigating)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_unreachable_focus_stops_without_walking_in_place() -> void:
	_wall(Vector2(30, 0), Vector2(10, 1080))
	await wait_physics_frames(2)
	var start: Vector2 = player.position
	_click_world(start + Vector2(96, 0))
	# Cold-cache planning is budgeted across frames rather than blocking a frame.
	for frame: int in range(240):
		await wait_physics_frames(1)
		if not navigation.is_navigating:
			break
	assert_false(navigation.is_navigating)
	assert_false(state.movement.has_target)
	assert_eq(player.position, start)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(sprite.animation, &"idle_right")
	assert_false(state.dust_particles.emitting)

func test_collidable_focus_is_approached_without_entering_it() -> void:
	var target: StaticBody2D = _wall(Vector2(96, 0), Vector2(16, 16))
	await wait_physics_frames(2)
	_click_world(target.position)
	await wait_seconds(1.5)
	assert_lte(player.position.distance_to(target.position), navigation.interaction_distance + state.movement.arrival_distance)
	assert_gt(player.position.distance_to(target.position), 12.0)
	assert_false(navigation.is_navigating)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq((player as FarmPlayer).animation.facing_direction, &"right")

func test_new_collision_replans_the_route() -> void:
	var focus: Vector2 = player.position + Vector2(180, 0)
	_click_world(focus)
	await wait_physics_frames(10)
	_wall(Vector2(32, 0), Vector2(10, 64))
	await wait_seconds(3.0)
	assert_lte(player.position.distance_to(focus), navigation.interaction_distance + state.movement.arrival_distance)
	assert_false(navigation.is_navigating)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_focus_route_fits_a_one_tile_wide_gate() -> void:
	# World-wide barrier with a 16px opening centered on x=960.
	_wall(Vector2(-484, -60), Vector2(952, 16))
	_wall(Vector2(484, -60), Vector2(952, 16))
	await wait_physics_frames(2)
	var focus: Vector2 = player.position + Vector2(0, -120)
	_click_world(focus)
	await wait_seconds(2.0)
	assert_lte(player.position.distance_to(focus), navigation.interaction_distance + state.movement.arrival_distance)
	assert_false(navigation.is_navigating)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_nearby_focus_only_turns_without_walking() -> void:
	var start: Vector2 = player.position
	_click_world(start + Vector2(0, -16))
	await wait_physics_frames(10)
	assert_eq(player.position, start)
	assert_false(navigation.is_navigating)
	assert_eq(sprite.animation, &"idle_up")

func test_inventory_cancels_focus_route() -> void:
	_click_world(player.position + Vector2(100, 0))
	await wait_physics_frames(5)
	var inventory_ui: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	inventory_ui.open()
	var stopped: Vector2 = player.position
	await wait_physics_frames(5)
	assert_false(navigation.has_focus)
	assert_eq(player.position, stopped)
	inventory_ui.close()
	await wait_physics_frames(5)
	assert_eq(player.position, stopped)

func test_collision_plays_idle_and_resumes_walking_when_path_clears() -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(10, 100)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = player.position + Vector2(30, 0)
	viewport.add_child(wall)
	await wait_physics_frames(2)
	_send_key(KEY_D, true)
	await wait_physics_frames(25)
	var blocked_position: Vector2 = player.position
	await wait_physics_frames(5)
	assert_almost_eq(player.position.x, blocked_position.x, 0.001)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(sprite.animation, &"idle_right")
	assert_false(state.dust_particles.emitting)
	wall.queue_free()
	await wait_physics_frames(10)
	assert_gt(player.position.x, blocked_position.x)
	assert_eq(state.current_state, StateComponent.State.WALK)
	_send_key(KEY_D, false)

func test_movement_dust_particles_emit_while_walking_and_stop_when_idle() -> void:
	var dust: GPUParticles2D = player.get_node_or_null("DustParticles")
	assert_not_null(dust, "Player must have DustParticles node")
	assert_not_null(state.dust_particles, "StateComponent must reference DustParticles")
	assert_false(dust.emitting, "Dust particles should not emit while idle")

	_send_key(KEY_D, true)
	await wait_physics_frames(10)
	assert_eq(state.current_state, StateComponent.State.WALK)
	assert_true(dust.emitting, "Dust particles should emit while walking")

	_send_key(KEY_D, false)
	await wait_physics_frames(15)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_false(dust.emitting, "Dust particles should stop emitting when idle")
