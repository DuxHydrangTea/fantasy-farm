extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/characters/player.tscn")
	var player: CharacterBody2D = scene.instantiate() as CharacterBody2D
	root.add_child(player)
	var state: Node = player.get_node("StateComponent")
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	await physics_frame
	check(sprite.animation == &"idle_down", "Starts idle facing down")
	check(not player.get_node("CollisionShape2D").disabled, "Feet collision enabled")
	var start: Vector2 = player.position
	Input.action_press(&"move_left")
	await create_timer(0.15).timeout
	check(player.position.x < start.x, "Moves left")
	check(sprite.animation == &"walk_right" and sprite.flip_h, "Left animation mirrors right")
	Input.action_release(&"move_left")
	await create_timer(0.2).timeout
	check(state.current_state == 0, "Returns to idle")
	# Inject physical keys so this also catches swapped InputMap arrow codes.
	var keys: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
	for index: int in range(keys.size()):
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = keys[index]
		event.pressed = true
		check(InputMap.event_is_action(event, actions[index % 4]), "Correct physical mapping: " + str(keys[index]))
		var before: Vector2 = player.position
		Input.parse_input_event(event)
		await create_timer(0.15).timeout
		var displacement: Vector2 = player.position - before
		check(displacement.dot(directions[index % 4]) > 0.0, "Correct movement for physical key: " + str(keys[index]))
		if index % 4 < 2:
			check(sprite.flip_h == (index % 4 == 0), "Correct facing for horizontal key")
		event.pressed = false
		Input.parse_input_event(event)
		await create_timer(0.2).timeout
	for slot: int in [0, 1]:
		player.get_node("ToolSelection").select_slot(slot)
		check(state.use_selected_tool(), "Uses selected tool")
		await physics_frame
		await physics_frame
		var expected: int = 2 if slot == 0 else 3
		check(state.current_state == expected, "Enters selected tool state")
		var locked_position: Vector2 = player.position
		Input.action_press(&"move_right")
		await create_timer(0.08).timeout
		check(player.position.is_equal_approx(locked_position), "Action locks movement")
		await create_timer(1.5).timeout
		check(state.current_state == 1, "Action finishes and resumes walking")
		Input.action_release(&"move_right")
		await create_timer(0.2).timeout
	check(state.STATE_NAMES.size() == 4, "Only Idle, Walk, Tool, Water states")
	player.queue_free()
	await process_frame
	print("Farmer Bob integration checks: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
