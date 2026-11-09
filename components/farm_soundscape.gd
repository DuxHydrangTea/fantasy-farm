class_name FarmSoundscape
extends Node2D
## A fixed pool, independent of herd size. Distances use the player's feet.
const RADIUS: float = 160.0
const CALLS: Array[StringName] = [&"animal_chicken", &"animal_duck", &"animal_cow", &"animal_sheep", &"animal_pig", &"animal_goose", &"animal_horse"]
var world: FarmWorld
var voices: Array[AudioStreamPlayer2D] = []
var sources: Array[WeakRef] = []
var _schedule: Dictionary = {}
var _elapsed: float = 0.0
var _scan_at: float = 0.0
var _next_call: float = 0.0
var _bee: AudioStreamPlayer2D
var _kitchen: AudioStreamPlayer2D
var _chef: WeakRef

static func distance_gain(distance: float, radius: float = RADIUS) -> float:
	return pow(clampf(1.0 - distance / radius, 0.0, 1.0), 1.6)

func _ready() -> void:
	var listener: AudioListener2D = AudioListener2D.new()
	listener.name = "FarmAudioListener"
	world.player.add_child(listener)
	listener.make_current()
	for index: int in range(2):
		voices.append(_voice(RADIUS))
		sources.append(null)
	_bee = _voice(112.0)
	_bee.stream = _loop(&"bees_loop")
	_kitchen = _voice(128.0)
	_kitchen.stream = _loop(&"kitchen_loop")
	world.workers.bridge.action_presented.connect(_worker_action)
	world.cooking.batch_completed.connect(_dish_ready)
	world.workers.wage_paid.connect(func() -> void: Sound.play(&"worker_wage"))

func _voice(radius: float) -> AudioStreamPlayer2D:
	var voice: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	voice.bus = &"Ambience"
	voice.max_distance = radius
	voice.attenuation = 0.0 # One explicit falloff, unaffected by camera zoom.
	add_child(voice)
	return voice

func _loop(event: StringName) -> AudioStreamWAV:
	var stream: AudioStreamWAV = (FarmSound.P1_CATALOG[event][0] as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream

func eligible(animal: AnimalActor) -> bool:
	return is_instance_valid(animal) and not animal.is_queued_for_deletion() and not animal._retired and not animal.is_dead() and animal.is_visible_in_tree() and world.is_ancestor_of(animal) and animal.definition != null and animal.behaviour != null and animal.behaviour.current_state not in [AnimalBehaviourComponent.State.SLEEP, AnimalBehaviourComponent.State.SLEEP_START]

func _process(delta: float) -> void:
	_elapsed += delta
	for index: int in range(voices.size()):
		var animal: AnimalActor = sources[index].get_ref() as AnimalActor if sources[index] != null else null
		if not voices[index].playing:
			sources[index] = null
		elif not eligible(animal):
			voices[index].stop()
			sources[index] = null
		else:
			_place(voices[index], animal.global_position)
	if _elapsed >= _scan_at:
		_scan_at = _elapsed + 0.35
		_scan()

func _place(voice: AudioStreamPlayer2D, point: Vector2) -> bool:
	voice.global_position = point
	var gain: float = distance_gain(world.player.global_position.distance_to(point), voice.max_distance)
	if gain <= 0.0001:
		voice.stop()
		return false
	voice.volume_db = linear_to_db(gain)
	return true

func _scan() -> void:
	var living: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		var animal: AnimalActor = node as AnimalActor
		if not eligible(animal):
			continue
		var id: int = animal.get_instance_id()
		living[id] = true
		var near: bool = world.player.global_position.distance_to(animal.global_position) < RADIUS
		if not near:
			_schedule.erase(id) # Returning to the pen starts with a fresh random delay.
			continue
		if not _schedule.has(id):
			_schedule[id] = _elapsed + randf_range(3.0, 9.0)
		if _elapsed < float(_schedule[id]) or _elapsed < _next_call:
			continue
		for index: int in range(voices.size()):
			if voices[index].playing:
				continue
			voices[index].stream = FarmSound.P1_CATALOG[CALLS[int(animal.definition.species)]][0] as AudioStream
			sources[index] = weakref(animal)
			if _place(voices[index], animal.global_position):
				voices[index].play()
			_schedule[id] = _elapsed + randf_range(12.0, 28.0)
			_next_call = _elapsed + randf_range(2.5, 4.0)
			break
	for id: Variant in _schedule.keys():
		if not living.has(id):
			_schedule.erase(id)
	var hive: Beehive
	var closest: float = _bee.max_distance
	for node: Node in get_tree().get_nodes_in_group(&"beehives"):
		var candidate: Beehive = node as Beehive
		if candidate == null or candidate.is_queued_for_deletion() or not candidate.repaired or not world.is_ancestor_of(candidate):
			continue
		var distance: float = world.player.global_position.distance_to(candidate.global_position)
		if distance < closest:
			closest = distance
			hive = candidate
	if hive != null:
		if _place(_bee, hive.global_position) and not _bee.playing:
			_bee.play()
	else:
		_bee.stop()
	var chef: ChefMerchant = _chef.get_ref() as ChefMerchant if _chef != null else null
	if not is_instance_valid(chef):
		for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
			if node is ChefMerchant and world.is_ancestor_of(node):
				chef = node as ChefMerchant
				_chef = weakref(chef)
				break
	if is_instance_valid(chef) and not world.cooking.queue.is_empty():
		if _place(_kitchen, chef.global_position) and not _kitchen.playing:
			_kitchen.play()
	else:
		_kitchen.stop()

func _dish_ready() -> void:
	var chef: ChefMerchant = _chef.get_ref() as ChefMerchant if _chef != null else null
	if is_instance_valid(chef) and world.player.global_position.distance_to(chef.global_position) < 128.0:
		Sound.play(&"cook_ready")

func _worker_action(kind: StringName, point: Vector2) -> void:
	if world.player.global_position.distance_to(point) >= 96.0:
		return
	var events: Dictionary = {&"till": &"till_soil", &"plant": &"sow_seed", &"water_crop": &"water_crop", &"harvest": &"harvest_crop", &"fruit": &"harvest_fruit", &"pickup": &"item_pickup", &"fertilize": &"fertilize_crop", &"treat_pests": &"spray_crop", &"treat_weeds": &"weed_remove", &"cure_animal": &"animal_care", &"feed": &"feed_trough", &"water_trough": &"water_trough"}
	if events.has(kind):
		Sound.play(events[kind])
