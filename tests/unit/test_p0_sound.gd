extends GutTest
var events: Array[StringName] = []
var old_clock: Callable
var tick: int = 10000
var old_levels: Array[float] = []

func before_each() -> void:
	events.clear()
	tick = 10000
	old_clock = Sound.clock
	old_levels.assign([FarmUI.master_volume, FarmUI.effects_volume, FarmUI.interface_volume, FarmUI.ambience_volume])
	Sound.stop_all()
	Sound.clock = func() -> int: return tick
	Sound.sound_played.connect(_played)

func after_each() -> void:
	Sound.sound_played.disconnect(_played)
	Sound.stop_all()
	Sound.clock = old_clock
	FarmUI.master_volume = old_levels[0]
	FarmUI.effects_volume = old_levels[1]
	FarmUI.interface_volume = old_levels[2]
	FarmUI.ambience_volume = old_levels[3]
	Sound.apply_volumes()

func _played(event: StringName, _stream: AudioStream) -> void:
	events.append(event)

func test_all_approved_events_load_real_nonlooping_audio_in_the_engine() -> void:
	assert_eq(Sound.CATALOG.size(), 23)
	var count: int = 0
	for clips: Array in Sound.CATALOG.values():
		for stream: AudioStream in clips:
			assert_gt(stream.get_length(), 0.015)
			assert_true(stream is AudioStreamWAV)
			assert_eq((stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)
			count += 1
	assert_eq(count, 48)

func test_mass_harvest_errors_and_pickups_coalesce_without_hiding_other_events() -> void:
	assert_true(Sound.play(&"harvest_crop"))
	for index: int in range(30):
		assert_false(Sound.play(&"harvest_crop"))
	assert_false(Sound.play(&"harvest_fruit"))
	assert_true(Sound.play(&"item_pickup"))
	assert_false(Sound.play(&"item_pickup"))
	assert_true(Sound.play(&"error_capacity"))
	assert_false(Sound.play(&"error_resources"))
	tick += 701
	assert_true(Sound.play(&"error_resources"))
	assert_eq(events.size(), 4)

func test_variations_do_not_repeat_and_the_voice_pool_is_bounded() -> void:
	var last_stream: AudioStream
	for index: int in range(FarmSound.VOICES):
		tick += 1000
		assert_true(Sound.play(&"sow_seed"))
		var voice: AudioStreamPlayer = Sound._sfx_players[index]
		if last_stream != null:
			assert_ne(voice.stream, last_stream)
		last_stream = voice.stream
	assert_eq(Sound.get_child_count(), FarmSound.VOICES)
	tick += 1000
	assert_false(Sound.play(&"footstep_dirt"))
	assert_eq(events.size(), FarmSound.VOICES)

func test_volume_channels_mute_independently_and_preferences_include_them() -> void:
	FarmUI.master_volume = 0.5
	FarmUI.effects_volume = 0.0
	FarmUI.interface_volume = 0.35
	FarmUI.ambience_volume = 0.6
	Sound.apply_volumes()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")))
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")))
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"UI"))), 0.35, 0.001)
	var path: String = "user://gut_p0_audio_preferences.cfg"
	assert_eq(FarmUI.save_preferences(path), OK)
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(path), OK)
	assert_eq(float(config.get_value("audio", "effects")), 0.0)
	assert_eq(float(config.get_value("audio", "interface")), 0.35)
	assert_eq(float(config.get_value("audio", "ambience")), 0.6)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_buttons_keep_click_feedback_alongside_transactions() -> void:
	var button: Button = Button.new()
	add_child_autofree(button)
	await wait_process_frames(2)
	button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(events, [&"ui_click"])
	tick += 1000
	button.pressed.emit()
	Sound.result({"ok":true}, &"coin_spend")
	await wait_process_frames(2)
	assert_eq(events, [&"ui_click", &"coin_spend", &"ui_click"])

func test_click_survives_its_handler_hiding_disabling_or_freeing_the_button() -> void:
	for action: String in ["hide", "disable", "free"]:
		Sound.stop_all()
		events.clear()
		tick += 1000
		var button: Button = Button.new()
		button.pressed.connect(func() -> void:
			if action == "hide": button.hide()
			elif action == "disable": button.disabled = true
			else: button.queue_free())
		add_child_autofree(button)
		button.pressed.emit()
		await wait_process_frames(2)
		assert_eq(events, [&"ui_click"], action)

func test_real_mouse_keyboard_and_disabled_button_input() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(320, 240)
	add_child_autofree(viewport)
	var button: Button = Button.new()
	button.position = Vector2(20, 20)
	button.size = Vector2(140, 50)
	viewport.add_child(button)
	await wait_process_frames(2)
	_mouse_click(viewport)
	await wait_process_frames(2)
	assert_eq(events, [&"ui_click"])
	tick += 1000
	button.grab_focus()
	var key: InputEventAction = InputEventAction.new()
	key.action = &"ui_accept"
	key.pressed = true
	viewport.push_input(key, true)
	key.pressed = false
	viewport.push_input(key, true)
	await wait_process_frames(2)
	assert_eq(events, [&"ui_click", &"ui_click"])
	tick += 1000
	button.disabled = true
	_mouse_click(viewport)
	await wait_process_frames(2)
	assert_eq(events.size(), 2)

func _mouse_click(viewport: SubViewport) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = Vector2(40, 40)
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(click, true)
	click.pressed = false
	click.button_mask = 0
	viewport.push_input(click, true)
