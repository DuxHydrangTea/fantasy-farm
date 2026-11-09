extends GutTest
var world: FarmWorld
var atmosphere: FarmAtmosphere
var old_music: float
var old_ambience: float

func before_each() -> void:
	old_music = FarmUI.music_volume
	old_ambience = FarmUI.ambience_volume
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	atmosphere = world.atmosphere

func after_each() -> void:
	FarmUI.music_volume = old_music
	FarmUI.ambience_volume = old_ambience
	Sound.apply_volumes()

func test_music_follows_the_same_local_hours_as_farm_lighting() -> void:
	for hour: float in [0.0, 4.9, 19.0, 23.9]:
		assert_eq(FarmAtmosphere.music_for_hour(hour), &"music_night")
	for hour: float in [5.0, 6.9, 16.5, 18.9]:
		assert_eq(FarmAtmosphere.music_for_hour(hour), &"music_twilight")
	for hour: float in [7.0, 12.0, 16.4]:
		assert_eq(FarmAtmosphere.music_for_hour(hour), &"music_day")
	var timestamp: float = world.farming.time_manager.now()
	world.weather.set_debug_hour(22)
	atmosphere._process(0.1)
	assert_eq(atmosphere.music_target, &"music_night")
	world.weather.set_debug_hour(12)
	atmosphere._process(0.1)
	assert_eq(atmosphere.music_target, &"music_day")
	assert_almost_eq(world.farming.time_manager.now(), timestamp, 0.2, "Preview does not advance farm time")

func test_wildlife_reacts_to_day_night_rain_and_wind() -> void:
	var day: Dictionary = FarmAtmosphere.environment_targets(12.0, WeatherManager.Weather.SUNNY, 1.0)
	var night: Dictionary = FarmAtmosphere.environment_targets(22.0, WeatherManager.Weather.SUNNY, 1.0)
	var rain: Dictionary = FarmAtmosphere.environment_targets(12.0, WeatherManager.Weather.RAIN, 1.0)
	var wind: Dictionary = FarmAtmosphere.environment_targets(12.0, WeatherManager.Weather.WINDY, 1.0)
	assert_gt(float(day[&"birds_day"]), 0.0)
	assert_eq(float(day[&"crickets_night"]), 0.0)
	assert_eq(float(night[&"birds_day"]), 0.0)
	assert_gt(float(night[&"crickets_night"]), 0.0)
	assert_almost_eq(float(rain[&"birds_day"]), float(day[&"birds_day"]) * 0.2, 0.001)
	assert_gt(float(rain[&"rain_loop"]), 0.0)
	assert_lt(float(wind[&"birds_day"]), float(day[&"birds_day"]))

func test_environment_fades_and_stops_inactive_loops_without_wind_duplication() -> void:
	atmosphere.advance_mix(12.0, WeatherManager.Weather.SUNNY, 1.0, 0.1)
	assert_gt(atmosphere.environment_weights[&"birds_day"], 0.0)
	assert_lt(atmosphere.environment_weights[&"birds_day"], 0.1)
	atmosphere.advance_mix(12.0, WeatherManager.Weather.SUNNY, 1.0, 4.0)
	assert_true(atmosphere.environment[&"birds_day"].playing)
	atmosphere.advance_mix(22.0, WeatherManager.Weather.RAIN, 1.0, 0.1)
	assert_true(atmosphere.environment[&"birds_day"].playing, "Outgoing bed fades, not cuts")
	atmosphere.advance_mix(22.0, WeatherManager.Weather.RAIN, 1.0, 4.0)
	assert_false(atmosphere.environment[&"birds_day"].playing)
	assert_true(atmosphere.environment[&"crickets_night"].playing)
	assert_true(atmosphere.environment[&"rain_loop"].playing)
	assert_false(atmosphere.environment.has(&"wind_loop"))
	atmosphere.advance_mix(22.0, WeatherManager.Weather.SUNNY, 1.0, 4.0)
	assert_false(atmosphere.environment[&"rain_loop"].playing)

func test_music_crossfades_and_rapid_return_reuses_the_playing_track() -> void:
	atmosphere.advance_mix(12.0, 0, 1.0, 5.0)
	var day_index: int = atmosphere._music_index
	assert_eq(atmosphere.music_weights[day_index], 1.0)
	atmosphere.advance_mix(22.0, 0, 1.0, 0.5)
	assert_true(atmosphere.music_voices[0].playing)
	assert_true(atmosphere.music_voices[1].playing)
	assert_gt(atmosphere.music_weights[day_index], 0.0)
	atmosphere.advance_mix(12.0, 0, 1.0, 0.1)
	assert_eq(atmosphere._music_index, day_index)
	assert_gt(atmosphere.music_weights[day_index], 0.8)
	atmosphere.advance_mix(12.0, 0, 1.0, 5.0)
	assert_false(atmosphere.music_voices[1 - day_index].playing)
	for index: int in range(100):
		atmosphere.advance_mix(float(index % 24), index % 4, 1.0, 0.1)
	assert_eq(atmosphere.get_child_count(), 5)
	assert_eq(atmosphere.music_voices.size(), 2)

func test_music_mute_is_independent_and_saved_with_settings() -> void:
	FarmUI.music_volume = 0.0
	FarmUI.ambience_volume = 0.6
	Sound.apply_volumes()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")))
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")))
	var path: String = "user://gut_p2_audio_preferences.cfg"
	assert_eq(FarmUI.save_preferences(path), OK)
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(path), OK)
	assert_eq(float(config.get_value("audio", "music")), 0.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings: TradeMenu = world.player.get_node("FarmSettings") as TradeMenu
	var sliders: Dictionary = settings.get("audio_sliders")
	assert_true(sliders.has(&"music"))

func test_all_streams_loop_and_unstarted_world_is_silent() -> void:
	assert_eq(FarmAtmosphere.CATALOG.size(), 6)
	for key: StringName in atmosphere.environment:
		assert_false(atmosphere.environment[key].playing)
		assert_eq(atmosphere.environment[key].bus, &"Ambience")
		assert_true((atmosphere.environment[key].stream as AudioStreamOggVorbis).loop)
	for key: StringName in FarmAtmosphere.CATALOG:
		assert_gt((FarmAtmosphere.CATALOG[key] as AudioStream).get_length(), 5.0)
	for voice: AudioStreamPlayer in atmosphere.music_voices:
		assert_false(voice.playing)
		assert_eq(voice.bus, &"Music")
