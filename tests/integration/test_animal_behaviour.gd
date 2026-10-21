extends GutTest
const CHICKEN: PackedScene = preload("res://scenes/animals/chicken.tscn")
const BASE: PackedScene = preload("res://scenes/animals/animal.tscn")
var pen: AnimalPen
var animal: AnimalActor
var behaviour: AnimalBehaviourComponent

func before_each() -> void:
	pen = AnimalPen.new()
	pen.bounds = Rect2(0, 0, 300, 200)
	add_child_autofree(pen)
	animal = CHICKEN.instantiate() as AnimalActor
	animal.definition = animal.definition.duplicate() as AnimalDefinition
	animal.definition.idle_seconds = Vector2(0.1, 0.1)
	animal.definition.forage_seconds = Vector2(0.15, 0.15)
	animal.definition.rest_seconds = Vector2(0.15, 0.15)
	animal.definition.sleep_seconds = Vector2(0.15, 0.15)
	animal.position = Vector2(120, 100)
	animal.get_node("WanderComponent").random_seed = 71
	pen.add_child(animal)
	behaviour = animal.behaviour
	await wait_physics_frames(2)

func _wait_for(state: AnimalBehaviourComponent.State, frames: int = 180) -> bool:
	for index: int in range(frames):
		if behaviour.current_state == state:
			return true
		await wait_physics_frames(1)
	return false

func test_sleep_completes_all_actual_transition_animations_in_order() -> void:
	var sequence: Array[StringName] = []
	behaviour.state_changed.connect(func(_previous: StringName, current: StringName) -> void: sequence.append(current))
	assert_true(behaviour.request_behaviour(&"sleep"))
	var position_before: Vector2 = animal.position
	assert_eq(animal.sprite.animation, &"sit_down")
	assert_false(behaviour.request_behaviour(&"walk"), "Cannot interrupt lying down")
	assert_false(behaviour.wake(), "Cannot wake before finishing the transition")
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SLEEP))
	assert_eq(animal.sprite.animation, &"sleep_down")
	assert_eq(animal.position, position_before)
	assert_false(animal.movement.has_target)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	assert_eq(sequence, [&"lie_down", &"sleep_start", &"sleep", &"stand_up", &"idle"])
	assert_eq(animal.position, position_before)
	assert_eq(animal.sprite.animation, &"idle_down")

func test_sitting_holds_last_frame_and_wakes_before_walking() -> void:
	animal.definition.rest_seconds = Vector2(10, 10)
	assert_true(behaviour.request_behaviour(&"rest"))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.REST))
	assert_eq(animal.sprite.animation, &"sit_down")
	assert_false(animal.sprite.is_playing())
	var before: Vector2 = animal.position
	animal.movement.set_target(Vector2(250, 100))
	await wait_physics_frames(3)
	assert_eq(animal.position, before)
	assert_false(animal.movement.has_target)
	assert_true(behaviour.wake())
	assert_eq(animal.sprite.animation, &"stand_up_down")
	assert_false(behaviour.request_behaviour(&"walk"))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	assert_true(behaviour.request_behaviour(&"walk"))

func test_peck_is_stationary_and_does_not_refill_food() -> void:
	assert_true(behaviour.request_behaviour(&"forage"))
	var before: Vector2 = animal.position
	var food: float = animal.needs.satiety
	assert_eq(animal.sprite.animation, &"peck_down")
	await wait_physics_frames(3)
	assert_eq(animal.position, before)
	assert_false(animal.movement.has_target)
	assert_lte(animal.needs.satiety, food)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))

func test_automatic_scheduler_chooses_configured_behaviour(action = use_parameters([&"forage", &"rest", &"sleep"])) -> void:
	animal.definition.walk_weight = 0.0
	animal.definition.forage_weight = 1.0 if action == &"forage" else 0.0
	animal.definition.rest_weight = 1.0 if action == &"rest" else 0.0
	animal.definition.sleep_weight = 1.0 if action == &"sleep" else 0.0
	assert_true(behaviour.request_behaviour(&"idle"))
	var expected: AnimalBehaviourComponent.State = AnimalBehaviourComponent.State.FORAGE if action == &"forage" else AnimalBehaviourComponent.State.LIE_DOWN
	assert_true(await _wait_for(expected))
	if action == &"sleep":
		assert_true(await _wait_for(AnimalBehaviourComponent.State.SLEEP))

func test_late_animation_completion_cannot_skip_or_repeat_states() -> void:
	assert_true(behaviour.request_behaviour(&"sleep"))
	animal.animation.action_finished.emit("stand_up")
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.LIE_DOWN)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SLEEP))
	animal.animation.action_finished.emit("sit")
	animal.animation.action_finished.emit("sleep_start")
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.SLEEP)
	assert_true(behaviour.wake())
	animal.animation.action_finished.emit("sleep_start")
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.STAND_UP)

func test_sleep_stays_inside_pen_and_missing_pen_cancels_safely() -> void:
	animal.definition.sleep_seconds = Vector2(10, 10)
	assert_true(behaviour.request_behaviour(&"sleep"))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SLEEP))
	animal.position = Vector2(-300, 800)
	await wait_physics_frames(2)
	assert_true(pen.contains_world(animal.global_position, animal.wander.margin))
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.SLEEP)
	animal.wander.pen = null
	await wait_physics_frames(2)
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_eq(animal.sprite.animation, &"idle_down")
	animal.animation.action_finished.emit("stand_up")
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.IDLE)

func test_missing_or_looping_optional_transitions_are_not_selected() -> void:
	var frames: SpriteFrames = animal.sprite.sprite_frames.duplicate() as SpriteFrames
	for name: String in frames.get_animation_names():
		if name != "idle_down" and name != "walk_down":
			frames.remove_animation(name)
	animal.sprite.sprite_frames = frames
	behaviour.configure(animal.definition)
	assert_false(behaviour.request_behaviour(&"forage"))
	assert_false(behaviour.request_behaviour(&"rest"))
	assert_false(behaviour.request_behaviour(&"sleep"))
	assert_true(behaviour.request_behaviour(&"walk"))
	frames = animal.definition.adult_frames.duplicate() as SpriteFrames
	frames.set_animation_loop(&"sit_down", true)
	animal.sprite.sprite_frames = frames
	behaviour.configure(animal.definition)
	assert_false(behaviour.request_behaviour(&"rest"), "A looping transition must not lock the state machine")

func test_other_species_resolve_their_own_forage_and_lying_animations(species_name = use_parameters(["cow", "sheep", "pig"])) -> void:
	var other: AnimalActor = BASE.instantiate() as AnimalActor
	var path: String = "res://animals/definitions/%s.tres" % species_name
	other.definition = load(path) as AnimalDefinition
	other.position = Vector2(200, 100)
	pen.add_child(other)
	assert_true(other.behaviour.request_behaviour(&"forage"))
	assert_ne(other.sprite.animation, &"peck_down")
	assert_true(other.behaviour.request_behaviour(&"rest"))
	assert_eq(other.sprite.animation, &"lie_down_down")

func test_all_chicken_and_rooster_assets_support_the_transition_chain() -> void:
	for index: int in range(1, 20):
		var path: String = "res://sprite_frames/animals/chicken_%02d_frames.tres" % index if index <= 18 else "res://sprite_frames/animals/rooster_frames.tres"
		var frames: SpriteFrames = load(path) as SpriteFrames
		for action: StringName in [&"sit_down", &"sleep_start_down", &"stand_up_down"]:
			assert_true(frames.has_animation(action), path + " " + String(action))
			assert_false(frames.get_animation_loop(action))
		for action: StringName in [&"peck_down", &"sleep_down"]:
			assert_true(frames.has_animation(action))
			assert_true(frames.get_animation_loop(action))

func test_focus_holds_idle_beyond_scheduler_timeout_then_automatic_walk_resumes() -> void:
	animal.definition.walk_weight = 1.0
	animal.definition.forage_weight = 0.0
	animal.definition.rest_weight = 0.0
	animal.definition.sleep_weight = 0.0
	assert_true(behaviour.request_behaviour(&"walk"))
	animal.set_status_focused(true)
	var before: Vector2 = animal.position
	watch_signals(behaviour)
	for index: int in range(30):
		animal.set_status_focused(true)
		await wait_physics_frames(1)
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_eq(animal.sprite.animation, &"idle_down")
	assert_eq(animal.position, before)
	assert_eq(animal.velocity, Vector2.ZERO)
	assert_false(animal.movement.has_target)
	assert_signal_emit_count(behaviour, "state_changed", 0, "Refresh does not restart idle")
	animal.set_status_focused(false)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.WALK))

func test_focus_wakes_lying_animal_and_ignores_stale_completion(state = use_parameters([
	AnimalBehaviourComponent.State.LIE_DOWN, AnimalBehaviourComponent.State.REST,
	AnimalBehaviourComponent.State.SLEEP_START, AnimalBehaviourComponent.State.SLEEP,
	AnimalBehaviourComponent.State.STAND_UP
])) -> void:
	animal.definition.rest_seconds = Vector2(10, 10)
	animal.definition.sleep_seconds = Vector2(10, 10)
	assert_true(behaviour.request_behaviour(&"rest" if state == AnimalBehaviourComponent.State.REST else &"sleep"))
	if state == AnimalBehaviourComponent.State.STAND_UP:
		assert_true(await _wait_for(AnimalBehaviourComponent.State.SLEEP))
		assert_true(behaviour.wake())
	else:
		assert_true(await _wait_for(state))
	animal.set_status_focused(true)
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.STAND_UP)
	animal.animation.action_finished.emit("sit")
	animal.animation.action_finished.emit("sleep_start")
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.STAND_UP)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	await wait_physics_frames(15)
	assert_eq(behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_eq(animal.sprite.animation, &"idle_down")
	animal.set_status_focused(false)
	assert_true(behaviour.request_behaviour(&"walk"))
