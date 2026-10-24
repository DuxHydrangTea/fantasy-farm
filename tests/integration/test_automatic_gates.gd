extends GutTest

const Gate = preload("res://components/automatic_gate.gd")
const GATE_PATHS: Array[String] = [
	"res://scenes/objects/outdoor_decor/horizontal_gate_left_hinge.tscn",
	"res://scenes/objects/outdoor_decor/horizontal_gate_right_hinge.tscn",
	"res://scenes/objects/outdoor_decor/vertical_gate.tscn",
]

func _player_at(point: Vector2) -> Node2D:
	var player: Node2D = Node2D.new()
	player.position = point
	player.add_to_group(&"farm_players")
	add_child_autofree(player)
	return player

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
