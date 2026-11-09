class_name FarmAtmosphere
extends Node
## World-owned loop mixer. Fades use linear gain; no tweens pile up on rapid changes.
## Two music voices adapt the Godot skill audio_manager crossfade template.
const CATALOG: Dictionary = preload("res://components/p2_sound_catalog.gd").LOOPS
const ENV_FADE: float = 3.0
const MUSIC_FADE: float = 5.0
const MUSIC_GAIN: float = 0.55
var world: FarmWorld
var environment: Dictionary[StringName, AudioStreamPlayer] = {}
var environment_weights: Dictionary[StringName, float] = {}
var music_voices: Array[AudioStreamPlayer] = []
var music_weights: Array[float] = [0.0, 0.0]
var music_keys: Array[StringName] = [&"", &""]
var music_target: StringName = &""
var _music_index: int = -1
var _music_weather_gain: float = 1.0

static func music_for_hour(hour: float) -> StringName:
	hour = fposmod(hour, 24.0)
	if hour < 5.0 or hour >= 19.0:
		return &"music_night"
	if hour < 7.0 or hour >= 16.5:
		return &"music_twilight"
	return &"music_day"

static func environment_targets(hour: float, weather: int, strength: float) -> Dictionary:
	hour = fposmod(hour, 24.0)
	var daylight: float = smoothstep(4.5, 7.0, hour) * (1.0 - smoothstep(17.0, 19.0, hour))
	var rain: float = clampf(strength, 0.0, 1.0) if weather == WeatherManager.Weather.RAIN else 0.0
	var wind: float = clampf(strength, 0.0, 1.0) if weather == WeatherManager.Weather.WINDY else 0.0
	var wildlife: float = (1.0 - 0.8 * rain) * (1.0 - 0.45 * wind)
	return {&"birds_day": daylight * wildlife * 0.55, &"crickets_night": (1.0 - daylight) * wildlife * 0.4, &"rain_loop": rain * 0.65}

func _ready() -> void:
	for key: StringName in [&"birds_day", &"crickets_night", &"rain_loop"]:
		var voice: AudioStreamPlayer = _voice(String(key), &"Ambience")
		voice.stream = _loop(key)
		environment[key] = voice
		environment_weights[key] = 0.0
	for index: int in range(2):
		music_voices.append(_voice("Music%d" % index, &"Music"))

func _voice(label: String, bus: StringName) -> AudioStreamPlayer:
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.name = label
	voice.bus = bus
	voice.volume_linear = 0.0
	add_child(voice)
	return voice

func _loop(key: StringName) -> AudioStreamOggVorbis:
	var stream: AudioStreamOggVorbis = (CATALOG[key] as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	return stream

func _process(delta: float) -> void:
	var timestamp: float = world.weather.display_timestamp(world.farming.time_manager.now())
	var hour: float = fposmod(timestamp + WeatherSchedule.UTC_OFFSET, WeatherSchedule.DAY) / 3600.0
	advance_mix(hour, world.weather.effects.active_weather, world.weather.effects.strength, delta)

func advance_mix(hour: float, weather: int, strength: float, delta: float) -> void:
	delta = maxf(0.0, delta)
	var targets: Dictionary = environment_targets(hour, weather, strength)
	for key: StringName in environment:
		var weight: float = move_toward(environment_weights[key], float(targets[key]), delta / ENV_FADE)
		environment_weights[key] = weight
		_apply(environment[key], weight)
	_request_music(music_for_hour(hour))
	var rain_duck: float = 0.75 if weather == WeatherManager.Weather.RAIN else 1.0
	_music_weather_gain = move_toward(_music_weather_gain, rain_duck, delta / ENV_FADE)
	for index: int in range(music_voices.size()):
		music_weights[index] = move_toward(music_weights[index], 1.0 if index == _music_index else 0.0, delta / MUSIC_FADE)
		_apply(music_voices[index], music_weights[index] * MUSIC_GAIN * _music_weather_gain)

func _request_music(key: StringName) -> void:
	if key == music_target:
		return
	music_target = key
	# A quick return during a crossfade reuses the still-playing track.
	for index: int in range(music_voices.size()):
		if music_keys[index] == key and music_voices[index].playing:
			_music_index = index
			return
	_music_index = 0 if music_weights[0] <= music_weights[1] else 1
	var voice: AudioStreamPlayer = music_voices[_music_index]
	voice.stop()
	voice.volume_linear = 0.0
	music_weights[_music_index] = 0.0
	music_keys[_music_index] = key
	voice.stream = _loop(key)

func _apply(voice: AudioStreamPlayer, gain: float) -> void:
	voice.volume_linear = gain
	if gain <= 0.0001:
		voice.stop()
	elif not voice.playing:
		voice.play()
