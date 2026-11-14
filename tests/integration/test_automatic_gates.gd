extends GutTest

const Gate = preload("res://components/automatic_gate.gd")
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SIGN_GATE_PATH: String = "res://scenes/objects/outdoor_decor/wooden_sign_gate.tscn"
const GATE_PATHS: Array[String] = [
	"res://scenes/objects/outdoor_decor/horizontal_gate_left_hinge.tscn",
	"res://scenes/objects/outdoor_decor/horizontal_gate_right_hinge.tscn",
	"res://scenes/objects/outdoor_decor/vertical_gate.tscn",
]

func test_farm_entrances_use_open_sign_gates_and_removed_openings_are_fenced() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	world.player.set_physics_process(false)
	await wait_physics_frames(2)
	var navigation: PlayerNavigationComponent = world.player.state.navigation
	var automatic_gates: Array[Node] = world.find_children("*", "StaticBody2D", true, false).filter(
		func(body: Node) -> bool: return body.get_script() == Gate)
	assert_true(automatic_gates.is_empty(), "The map should have no automatic gates")
	for name: String in ["FarmlandEntrance", "CoopEntrance", "BarnEntrance", "PondEntrance", "StorageYard/ProduceEntrance", "StorageYard/SeedEntrance"]:
		var gate: StaticBody2D = world.get_node_or_null(name)
		assert_not_null(gate, name)
		if gate == null:
			continue
		assert_eq(gate.scene_file_path, SIGN_GATE_PATH, name)
		var from_north: Vector2 = gate.global_position + Vector2(0, -30)
		var from_south: Vector2 = gate.global_position + Vector2(0, 22)
		assert_true(navigation._segment_clear(from_north, from_south), "%s stays clear from the north" % name)
		assert_true(navigation._segment_clear(from_south, from_north), "%s stays clear from the south" % name)
	for x: int in [1000, 1400]:
		assert_false(navigation._segment_clear(Vector2(x - 20, 432), Vector2(x + 20, 432)), "Coop sides are closed")
		assert_false(navigation._segment_clear(Vector2(x - 20, 728), Vector2(x + 20, 728)), "Barn sides are closed")
	assert_false(navigation._segment_clear(Vector2(1192, 532), Vector2(1192, 563)), "Coop south fence is closed")
	assert_false(navigation._segment_clear(Vector2(537, 265), Vector2(537, 303)), "Old farmland entrance is closed")

func test_holding_down_from_beside_farmland_gate_enters_through_the_opening() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	var gate: Node2D = world.get_node("FarmlandEntrance")
	world.player.global_position = gate.global_position + Vector2(54, -19)
	await wait_physics_frames(2)
	Input.action_press(&"move_down")
	await wait_physics_frames(95)
	Input.action_release(&"move_down")
	assert_gt(world.player.global_position.y, gate.global_position.y + 32.0)
	assert_lt(absf(world.player.global_position.x - gate.global_position.x), 18.0)

func _player_at(point: Vector2) -> Node2D:
	var player: Node2D = Node2D.new()
	player.position = point
	player.add_to_group(&"farm_players")
	add_child_autofree(player)
	return player

func test_vertical_gate_sorts_sprite_at_its_own_y_position() -> void:
	var gate: Gate = (load(GATE_PATHS[2]) as PackedScene).instantiate() as Gate
	add_child_autofree(gate)
	var sprite: AnimatedSprite2D = gate.get_node("AnimatedSprite2D")
	assert_true(gate.y_sort_enabled, "The animated sprite must participate in world Y-sort")
	assert_eq(sprite.position.y, -24.0, "Sort the tall gate near its center")

func test_all_gate_scenes_open_hold_and_close_with_real_animation_playback() -> void:
	var player: Node2D = _player_at(Vector2(200, 0))
	for path: String in GATE_PATHS:
		var gate: Gate = (load(path) as PackedScene).instantiate() as Gate
		add_child_autofree(gate)
		var sprite: AnimatedSprite2D = gate.get_node("AnimatedSprite2D")
		assert_eq(sprite.animation, &"closed", path)
		player.position = Vector2(40, 0)
		await wait_physics_frames(2)
		assert_eq(sprite.animation, &"open", path)
		await wait_seconds(0.75)
		assert_eq(sprite.animation, &"opened", path)
		player.position = Vector2(56, 0)
		await wait_physics_frames(2)
		assert_eq(sprite.animation, &"opened", "Stay open between the two radii")
		player.position = Vector2(200, 0)
		await wait_physics_frames(2)
		assert_eq(sprite.animation, &"close", path)
		await wait_seconds(0.75)
		assert_eq(sprite.animation, &"closed", path)
		gate.free()

func test_player_already_nearby_and_multiple_players() -> void:
	var first: Node2D = _player_at(Vector2.ZERO)
	var second: Node2D = _player_at(Vector2(20, 0))
	var gate: Gate = (load(GATE_PATHS[2]) as PackedScene).instantiate() as Gate
	add_child_autofree(gate)
	assert_true(gate.is_open, "Detect a player present before the gate enters the tree")
	first.position = Vector2(200, 0)
	await wait_physics_frames(2)
	assert_true(gate.is_open, "One remaining player keeps the gate open")
	second.queue_free()
	await wait_physics_frames(3)
	assert_false(gate.is_open, "Removing the last nearby player closes the gate")

func test_non_player_is_ignored_and_turning_back_reverses_without_pose_jump() -> void:
	var animal: Node2D = Node2D.new()
	add_child_autofree(animal)
	var player: Node2D = _player_at(Vector2(200, 0))
	var gate: Gate = (load(GATE_PATHS[0]) as PackedScene).instantiate() as Gate
	add_child_autofree(gate)
	var sprite: AnimatedSprite2D = gate.get_node("AnimatedSprite2D")
	await wait_physics_frames(2)
	assert_false(gate.is_open, "Nearby decorations and animals do not open the gate")
	player.position = Vector2.ZERO
	await wait_seconds(0.25)
	var opening_frame: int = sprite.frame
	player.position = Vector2(200, 0)
	gate._update_proximity()
	assert_eq(sprite.animation, &"close")
	assert_eq(sprite.frame, 4 - opening_frame, "Reverse from the matching visual pose")
	player.position = Vector2.ZERO
	gate._update_proximity()
	assert_eq(sprite.animation, &"open")
	assert_eq(sprite.frame, opening_frame)
	await wait_seconds(0.75)
	assert_eq(sprite.animation, &"opened")
