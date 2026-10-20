class_name AnimalBehaviourComponent
extends Node

## Small state machine adapted from the Godot skill's state-machine template.
## Owns behaviour decisions; Wander owns targets and Movement owns physics.
signal state_changed(previous: StringName, current: StringName)
enum State { IDLE, WALK, FORAGE, LIE_DOWN, REST, SLEEP_START, SLEEP, STAND_UP, SEEK_RESOURCE, EAT, DRINK }
const STATE_NAMES: Array[StringName] = [&"idle", &"walk", &"forage", &"lie_down", &"rest", &"sleep_start", &"sleep", &"stand_up", &"seek_resource", &"eat", &"drink"]
@export var wander: AnimalWanderComponent
@export var foraging: AnimalForagingComponent
var current_state: State = State.IDLE
var definition: AnimalDefinition
var _remaining: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _forage_action: StringName = &""
var _lie_down_action: StringName = &""
var _expected_action: StringName = &""
var _sleep_after_lying: bool = false
var _first_decision: bool = true

func _ready() -> void:
	wander.animation.action_finished.connect(_on_animation_finished)

func configure(data: AnimalDefinition) -> void:
	definition = data
	wander.set_physics_process(false)
	if wander.random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = wander.random_seed + 1
	_forage_action = _resolve_action(data.forage_action, [&"peck", &"graze", &"chew"])
	_lie_down_action = _resolve_action(data.lie_down_action, [&"sit", &"lie_down"])
	_enter(State.IDLE)
	_remaining = 0.0

func _physics_process(delta: float) -> void:
	if definition == null:
		return
	foraging.advance(delta)
	if not is_instance_valid(wander.pen):
		foraging.cancel()
		_stop()
		if current_state != State.IDLE:
			_enter(State.IDLE)
		return
	# Boundary enforcement remains active while sitting or sleeping.
	wander._keep_inside()
	if wander.traversal != null and wander.traversal.handle_laying(delta):
		return
	if current_state == State.SEEK_RESOURCE:
		var travel: AnimalForagingComponent.Travel = foraging.step(delta)
		if travel == AnimalForagingComponent.Travel.ARRIVED:
			_enter(State.EAT if foraging.target.kind == AnimalTrough.Kind.FOOD else State.DRINK)
		elif travel == AnimalForagingComponent.Travel.FAILED:
			foraging.cancel(true)
			_enter(State.IDLE)
		return
	if current_state == State.EAT or current_state == State.DRINK:
		_stop()
		if not foraging.target_is_valid():
			foraging.cancel(true)
			_enter(State.IDLE)
			return
		_remaining -= delta
		if _remaining <= 0.0:
			foraging.finish()
			foraging.cancel()
			_enter(State.IDLE)
		return
	if current_state == State.IDLE or current_state == State.WALK or current_state == State.FORAGE:
		if foraging.try_begin():
			_enter(State.SEEK_RESOURCE)
			return
	elif (current_state == State.REST or current_state == State.SLEEP) and foraging.has_need():
		wake()
		return
	if current_state == State.WALK:
		wander.step(delta)
		if not wander.movement.has_target:
			_enter(State.IDLE)
		return
	_stop()
	# Các bước nằm xuống/bắt đầu ngủ/đứng dậy phải chờ animation one-shot kết thúc thật.
	# Không chuyển bằng bộ đếm nghỉ ở dưới, vì mỗi loài có số frame/tốc độ khác nhau.
	# Nếu bỏ nhánh chờ này, con vật có thể trượt đi trong tư thế nằm hoặc bỏ qua bước đứng dậy.
	if current_state == State.LIE_DOWN or current_state == State.SLEEP_START or current_state == State.STAND_UP:
		return # Only completion of the actual one-shot animation advances this state.
	_remaining -= delta
	if _remaining > 0.0:
		return
	match current_state:
		State.IDLE:
			_choose_behaviour()
		State.FORAGE:
			_enter(State.IDLE)
		State.REST, State.SLEEP:
			wake()

## Upright behaviours can be interrupted. A lying animal must wake() first.
func request_behaviour(action: StringName) -> bool:
	if definition == null or not is_instance_valid(wander.pen):
		return false
	if current_state != State.IDLE and current_state != State.WALK and current_state != State.FORAGE:
		return false
	match action:
		&"walk":
			if not wander.choose_target():
				return false
			_enter(State.WALK)
		&"idle":
			_enter(State.IDLE)
		&"forage":
			if _forage_action.is_empty():
				return false
			_enter(State.FORAGE)
		&"rest", &"sleep":
			if wander.traversal != null and wander.traversal.is_swimming():
				_enter(State.SLEEP if action == &"sleep" else State.IDLE)
				return true
			if not _can_rest() or (action == &"sleep" and not _has_action(&"sleep")):
				return false
			_sleep_after_lying = action == &"sleep"
			_enter(State.LIE_DOWN)
		_:
			return false
	_first_decision = false
	return true

func wake() -> bool:
	if current_state != State.REST and current_state != State.SLEEP:
		return false
	if wander.traversal != null and wander.traversal.is_swimming():
		_enter(State.IDLE)
		return true
	_enter(State.STAND_UP)
	return true

func _choose_behaviour() -> void:
	if _first_decision:
		_first_decision = false
		if request_behaviour(&"walk"):
			return
	var choices: Array[StringName] = [&"walk", &"forage", &"rest", &"sleep"]
	var weights: Array[float] = [maxf(0.0, definition.walk_weight), maxf(0.0, definition.forage_weight) if not _forage_action.is_empty() else 0.0, maxf(0.0, definition.rest_weight) if _can_rest() else 0.0, maxf(0.0, definition.sleep_weight) if _can_rest() and _has_action(&"sleep") else 0.0]
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var draw: float = _rng.randf() * total
	for index: int in range(choices.size()):
		if weights[index] > 0.0 and draw < weights[index]:
			if request_behaviour(choices[index]):
				return
			break
		draw -= weights[index]
	_enter(State.IDLE)

func _enter(next: State) -> void:
	var previous: StringName = STATE_NAMES[current_state]
	current_state = next
	_expected_action = &""
	if next != State.WALK and next != State.SEEK_RESOURCE:
		_stop()
	match next:
		State.IDLE:
			_remaining = _duration(definition.idle_seconds)
			_play(&"idle")
		State.WALK:
			_play(&"walk")
		State.FORAGE:
			_remaining = _duration(definition.forage_seconds)
			_play(_forage_action)
		State.LIE_DOWN:
			_play(_lie_down_action)
		State.REST:
			_remaining = _duration(definition.rest_seconds)
			# Keep the final lying-down frame, without restarting the animation.
		State.SLEEP_START:
			_play(&"sleep_start")
		State.SLEEP:
			_remaining = _duration(definition.sleep_seconds)
			_play(&"sleep")
		State.STAND_UP:
			_play(&"stand_up")
		State.SEEK_RESOURCE:
			_play(&"walk")
		State.EAT, State.DRINK:
			_remaining = maxf(0.05, foraging.target.serving_seconds)
			_play(_forage_action if not _forage_action.is_empty() else &"idle")
	if previous != STATE_NAMES[next]:
		state_changed.emit(previous, STATE_NAMES[next])

func _on_animation_finished(action: String) -> void:
	if action != String(_expected_action):
		return
	match current_state:
		State.LIE_DOWN:
			if _sleep_after_lying:
				_enter(State.SLEEP_START if _one_shot(&"sleep_start") else State.SLEEP)
			else:
				_enter(State.REST)
		State.SLEEP_START:
			_enter(State.SLEEP)
		State.STAND_UP:
			_enter(State.IDLE)

func _play(action: StringName) -> void:
	_expected_action = action
	wander.animation.play(String(action), true)

func _stop() -> void:
	wander.cancel_destination()

func _has_action(action: StringName) -> bool:
	var frames: SpriteFrames = wander.animation.animated_sprite.sprite_frames
	var animation_name: StringName = StringName(String(action) + "_down")
	return frames != null and frames.has_animation(animation_name) and frames.get_frame_count(animation_name) > 0

func _one_shot(action: StringName) -> bool:
	return _has_action(action) and not wander.animation.animated_sprite.sprite_frames.get_animation_loop(StringName(String(action) + "_down"))

func _can_rest() -> bool:
	return not _lie_down_action.is_empty() and _one_shot(_lie_down_action) and _one_shot(&"stand_up")

func _resolve_action(configured: StringName, candidates: Array[StringName]) -> StringName:
	if not configured.is_empty():
		return configured if _has_action(configured) else &""
	for action: StringName in candidates:
		if _has_action(action):
			return action
	return &""

func _duration(seconds: Vector2) -> float:
	return _rng.randf_range(maxf(0.05, seconds.x), maxf(maxf(0.05, seconds.x), seconds.y))
