class_name FarmSound
extends Node
## Bounded voice pool adapted from the Godot skill's audio_manager template.
## Presentation only. No wallet/inventory-delta inference, including during loads.
signal sound_played(event: StringName, stream: AudioStream)
const VOICES: int = 12
const CATALOG: Dictionary = preload("res://components/p0_sound_catalog.gd").CLIPS
const P1_CATALOG: Dictionary = preload("res://components/p1_sound_catalog.gd").CLIPS
var _sfx_players: Array[AudioStreamPlayer] = []
var _last: Dictionary = {}
var _variant: Dictionary = {}
var clock: Callable = func() -> int: return Time.get_ticks_msec()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in [&"SFX", &"UI", &"Ambience", &"Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	FarmUI.load_preferences()
	apply_volumes()
	for index: int in range(VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Sfx%d" % index
		add_child(voice)
		_sfx_players.append(voice)
	get_tree().node_added.connect(_node_added)

func apply_volumes() -> void:
	_set_volume(&"Master", FarmUI.master_volume)
	_set_volume(&"SFX", FarmUI.effects_volume)
	_set_volume(&"UI", FarmUI.interface_volume)
	_set_volume(&"Ambience", FarmUI.ambience_volume)
	_set_volume(&"Music", FarmUI.music_volume)

func _set_volume(bus: StringName, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, value)))

func _group(event: StringName) -> StringName:
	if String(event).begins_with("error_"):
		return &"errors"
	if String(event).begins_with("collect_"):
		return &"item_pickup"
	if event == &"worker_wage":
		return &"wages"
	if String(event).begins_with("harvest_"):
		return &"harvest"
	if String(event).begins_with("footstep_"):
		return &"steps"
	return event

func _cooldown(group: StringName) -> int:
	return 2000 if group == &"wages" else 700 if group == &"errors" else 220 if group == &"steps" else 130 if group == &"harvest" else 120 if group == &"item_pickup" else 70

func play(event: StringName) -> bool:
	if (not CATALOG.has(event) and not P1_CATALOG.has(event)) or not is_inside_tree():
		return false
	var now: int = int(clock.call())
	var group: StringName = _group(event)
	if now - int(_last.get(group, -100000)) < _cooldown(group):
		return false
	var voice: AudioStreamPlayer
	for candidate: AudioStreamPlayer in _sfx_players:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		return false # Never cut off a reward/confirmation to make room for a footstep.
	var clips: Array = CATALOG[event] if CATALOG.has(event) else P1_CATALOG[event]
	var previous: int = int(_variant.get(event, -1))
	var index: int = randi_range(0, clips.size() - 1)
	if clips.size() > 1 and index == previous:
		index = (index + 1) % clips.size()
	_variant[event] = index
	_last[group] = now
	var ui: bool = String(event).begins_with("ui_") or group == &"errors" or event in [&"order_delivered", &"objective_complete", &"reward_claim", &"coin_receive", &"coin_spend"]
	voice.bus = &"UI" if ui else &"SFX"
	voice.stream = clips[index] as AudioStream
	voice.volume_db = 3.0 if event in [&"ui_click", &"ui_tab"] else 0.0
	voice.pitch_scale = 1.0 # UI clips are now soft foley, not pitched electronic tones.
	voice.play()
	sound_played.emit(event, voice.stream)
	return true

static func collection_event(item_id: StringName, fallback: StringName = &"item_pickup") -> StringName:
	if item_id in [&"chicken_egg", &"duck_egg", &"goose_egg"]:
		return &"collect_egg"
	if item_id == &"cow_milk":
		return &"collect_milk"
	if item_id == &"sheep_wool":
		return &"collect_wool"
	if item_id == &"pig_truffle":
		return &"collect_truffle"
	if String(item_id).begins_with("honey") or String(item_id).ends_with("honey"):
		return &"collect_honey"
	return fallback

func result(result_data: Dictionary, success: StringName) -> void:
	if result_data.get("ok", false):
		play(success)
	else:
		var error: String = String(result_data.get("error", "")).to_lower()
		play(&"error_capacity" if "space" in error or "full" in error or "capacity" in error else &"error_resources")

func _node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button(weakref(node))
	elif node is TabBar:
		(node as TabBar).tab_clicked.connect(func(_index: int) -> void: _button_feedback(&"ui_tab"))

func _bind_button(reference: WeakRef) -> void:
	var button: BaseButton = reference.get_ref() as BaseButton
	if not is_instance_valid(button) or button.has_meta(&"sound_bound"):
		return
	button.set_meta(&"sound_bound", true)
	button.pressed.connect(_button_pressed.bind(reference))
	if button is OptionButton:
		(button as OptionButton).item_selected.connect(func(_index: int) -> void: _button_feedback(&"ui_click"))

func _button_pressed(reference: WeakRef) -> void:
	var button: BaseButton = reference.get_ref() as BaseButton
	if is_instance_valid(button) and button.get_meta(&"sound_silent", false):
		return
	# Capture the activation, not the post-command widget. Its handler may hide,
	# disable, rebuild or free the button before the deferred audio runs.
	var event: StringName = &"ui_tab" if is_instance_valid(button) and button.toggle_mode else &"ui_click"
	_button_feedback.call_deferred(event)

func _button_feedback(event: StringName) -> void:
	play(event)

func stop_all() -> void:
	for voice: AudioStreamPlayer in _sfx_players:
		voice.stop()
	_last.clear()
