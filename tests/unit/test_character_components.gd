extends GutTest

const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var player: CharacterBody2D
var movement: MovementComponent
var animation: AnimationComponent
var state: StateComponent
var sprite: AnimatedSprite2D

func before_each() -> void:
	player = PLAYER.instantiate() as CharacterBody2D
	add_child_autofree(player)
	movement = player.get_node("MovementComponent")
	animation = player.get_node("AnimationComponent")
	state = player.get_node("StateComponent")
	sprite = player.get_node("AnimatedSprite2D")
	state.set_physics_process(false)
	sprite.stop()

func test_diagonal_movement_does_not_exceed_speed() -> void:
	movement.move(Vector2(1, 1), 1.0)
	assert_almost_eq(player.velocity.length(), movement.speed, 0.001)
	assert_gt(player.velocity.x, 0.0)
	assert_gt(player.velocity.y, 0.0)

func test_friction_stops_the_character() -> void:
	movement.move(Vector2.RIGHT, 1.0)
	movement.move(Vector2.ZERO, 1.0)
	assert_eq(player.velocity, Vector2.ZERO)

func test_stop_clears_velocity_immediately() -> void:
	player.velocity = Vector2(100, -100)
	movement.stop()
	assert_eq(player.velocity, Vector2.ZERO)

func test_left_mirrors_right_and_right_clears_flip() -> void:
	animation.face(Vector2.LEFT)
	animation.play("walk")
	assert_eq(sprite.animation, &"walk_right")
	assert_true(sprite.flip_h)
	animation.face(Vector2.RIGHT)
	assert_eq(sprite.animation, &"walk_right")
	assert_false(sprite.flip_h)

func test_idle_keeps_last_facing_direction() -> void:
	animation.face(Vector2.UP)
	animation.update_facing_direction(Vector2.ZERO)
	animation.play("idle")
	assert_eq(sprite.animation, &"idle_up")

func test_state_transition_emits_once_and_stops_movement() -> void:
	watch_signals(state)
	player.velocity = Vector2.RIGHT * 100.0
	state.transition_to(StateComponent.State.TOOL)
	state.transition_to(StateComponent.State.TOOL)
	assert_eq(player.velocity, Vector2.ZERO)
	assert_signal_emit_count(state, "state_changed", 1)
	assert_signal_emitted_with_parameters(state, "state_changed", [&"idle", &"tool"])

func test_unrelated_animation_completion_does_not_end_action() -> void:
	state.transition_to(StateComponent.State.WATER)
	animation.action_finished.emit("tool")
	assert_eq(state.current_state, StateComponent.State.WATER)
	animation.action_finished.emit("water")
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_player_has_no_faint_state() -> void:
	assert_eq(state.STATE_NAMES, [&"idle", &"walk", &"tool", &"water"])
