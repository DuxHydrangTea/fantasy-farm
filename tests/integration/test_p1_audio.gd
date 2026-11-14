extends GutTest
var world: FarmWorld
var soundscape: FarmSoundscape
var animal: AnimalActor
var events: Array[StringName] = []

func before_each() -> void:
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	soundscape = world.soundscape
	world.player.global_position = Vector2(10000, 10000)
	var pen: AnimalPen = AnimalPen.new()
	pen.bounds = Rect2(9900, 9900, 400, 400)
	world.add_child(pen)
	animal = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	animal.pen = pen
	animal.position = world.player.global_position + Vector2(20, 0)
	world.add_child(animal)
	Sound.stop_all()
	events.clear()
	Sound.sound_played.connect(_played)

func after_each() -> void:
	Sound.sound_played.disconnect(_played)
	Sound.stop_all()

func _played(event: StringName, _stream: AudioStream) -> void:
	events.append(event)

func _call() -> void:
	soundscape._schedule[animal.get_instance_id()] = 0.0
	soundscape._next_call = 0.0
	soundscape._scan()

func test_calls_follow_player_distance_and_stop_exactly_outside_radius() -> void:
	_call()
	var voice: AudioStreamPlayer2D = soundscape.voices[0]
	assert_true(voice.playing)
	assert_eq(voice.bus, &"Ambience")
	var near_db: float = voice.volume_db
	animal.global_position = world.player.global_position + Vector2(180, 0)
	soundscape._process(0.01)
	assert_lt(voice.volume_db, near_db - 10.0)
	animal.global_position = world.player.global_position + Vector2(FarmSoundscape.RADIUS, 0)
	soundscape._process(0.01)
	assert_false(voice.playing)
	_call()
	assert_false(voice.playing)
	assert_eq(FarmSoundscape.distance_gain(FarmSoundscape.RADIUS), 0.0)

func test_sleeping_hidden_retired_and_foreign_animals_are_silent() -> void:
	animal.behaviour.current_state = AnimalBehaviourComponent.State.SLEEP
	_call()
	assert_false(soundscape.voices[0].playing)
	animal.behaviour.current_state = AnimalBehaviourComponent.State.IDLE
	_call()
	assert_true(soundscape.voices[0].playing)
	animal.hide()
	soundscape._process(0.01)
	assert_false(soundscape.voices[0].playing)
	animal.show()
	animal._retired = true
	assert_false(soundscape.eligible(animal))

func test_pool_is_bounded_and_call_delays_prevent_herd_bursts() -> void:
	_call()
	assert_eq(soundscape.voices.size(), 2)
	assert_between(float(soundscape._schedule[animal.get_instance_id()]) - soundscape._elapsed, 6.0, 12.0)
	assert_gt(soundscape._next_call, soundscape._elapsed + 2.0)
	soundscape._scan()
	assert_false(soundscape.voices[1].playing)
	var reference: WeakRef = weakref(animal)
	animal.queue_free()
	await wait_frames(2)
	soundscape._process(0.4)
	assert_null(reference.get_ref())
	assert_false(soundscape.voices[0].playing)
	assert_true(soundscape._schedule.is_empty())

func test_nearby_herd_calls_sooner_and_prioritizes_the_closest_due_animal() -> void:
	animal.position.x += 140.0
	soundscape._schedule[animal.get_instance_id()] = 0.0
	var closest: AnimalActor
	for index: int in range(5):
		var chicken: AnimalActor = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
		chicken.pen = animal.pen
		chicken.position = world.player.global_position + Vector2(24.0 + index * 10.0, 0.0)
		world.add_child(chicken)
		soundscape._schedule[chicken.get_instance_id()] = 0.0
		if index == 0:
			closest = chicken
	soundscape._scan()
	assert_true(soundscape.voices[0].playing)
	assert_eq(soundscape.sources[0].get_ref(), closest)
	assert_between(soundscape._next_call - soundscape._elapsed, 1.0, 1.6)
	assert_false(soundscape.voices[1].playing)

func test_every_species_has_a_valid_quiet_nonlooping_call() -> void:
	for event: StringName in FarmSoundscape.CALLS:
		var clip: AudioStreamWAV = FarmSound.P1_CATALOG[event][0] as AudioStreamWAV
		assert_gt(clip.get_length(), 0.15)
		assert_eq(clip.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(FarmSound.P1_CATALOG.size(), 32)
	assert_eq((soundscape._bee.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq((soundscape._kitchen.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)

func test_load_catch_up_stays_silent_and_live_cooking_emits_once() -> void:
	var cooking: ChefCooking = ChefCooking.new()
	var completed: Array[int] = []
	cooking.batch_completed.connect(func() -> void: completed.append(1))
	cooking.restore({"queue": [{"recipe": "fried_egg", "finish_at": 5.0}], "ready": [], "updated_at": 0.0}, 10.0)
	assert_true(completed.is_empty())
	cooking.queue.append({"recipe": "fried_egg", "finish_at": 15.0})
	cooking.advance(16.0)
	cooking.advance(17.0)
	assert_eq(completed.size(), 1)

func test_worker_feedback_is_nearby_and_success_only_events_are_explicit() -> void:
	soundscape._worker_action(&"feed", world.player.global_position + Vector2(200, 0))
	assert_true(events.is_empty())
	soundscape._worker_action(&"feed", world.player.global_position + Vector2(20, 0))
	assert_eq(events, [&"feed_trough"])
	soundscape._worker_action(&"patrol", world.player.global_position)
	assert_eq(events.size(), 1)
	assert_eq(FarmSound.collection_event(&"duck_egg"), &"collect_egg")
	assert_eq(FarmSound.collection_event(&"cow_milk"), &"collect_milk")
