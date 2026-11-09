extends Node
## Save-isolated mixer and rendered settings verification. Use --audio-driver Dummy.
const OUTPUT: String = "C:/projects/fantasy-farm/.godot/p0-audio-probe"
var player: FarmPlayer

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var levels: Array[float] = [FarmUI.master_volume, FarmUI.effects_volume, FarmUI.interface_volume, FarmUI.ambience_volume]
	FarmUI.master_volume = 1.0
	FarmUI.effects_volume = 1.0
	FarmUI.interface_volume = 1.0
	Sound.apply_volumes()
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	var measured: Array[Dictionary] = []
	for event: StringName in [&"ui_click", &"till_soil", &"water_crop", &"harvest_crop", &"coin_receive", &"order_delivered"]:
		Sound.stop_all()
		capture.clear_buffer()
		assert(Sound.play(event))
		await get_tree().create_timer(0.3).timeout
		var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		var peak: float = 0.0
		for sample: Vector2 in frames:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		assert(peak > 0.0001, "Silent mixer output: " + String(event))
		measured.append({"event": String(event), "frames": frames.size(), "peak": peak})
	AudioServer.remove_bus_effect(0, index)
	Sound.stop_all()
	FarmUI.master_volume = levels[0]
	FarmUI.effects_volume = levels[1]
	FarmUI.interface_volume = levels[2]
	FarmUI.ambience_volume = levels[3]
	Sound.apply_volumes()
	player = preload("res://scenes/characters/player.tscn").instantiate() as FarmPlayer
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	var settings: TradeMenu = player.get_node("FarmSettings") as TradeMenu
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		get_tree().root.size = size
		get_tree().root.content_scale_size = size
		for language: String in ["en", "vi"]:
			Language.set_language(language)
			settings.call("show_settings")
			var panel: PanelContainer = settings.get("panel") as PanelContainer
			var scroll: ScrollContainer = panel.find_child("SettingsScroll", true, false) as ScrollContainer
			scroll.scroll_vertical = 0
			await _shot("settings-%s-top" % language, panel)
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await _shot("settings-%s-audio" % language, panel)
			settings.close(false)
	assert(SaveManager.adapter == null)
	var file: FileAccess = FileAccess.open(OUTPUT.path_join("mixer_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":true, "mixer_outputs":measured, "settings_layouts":4, "save_adapter_bound":false}, "\t"))
	print("P0_AUDIO_PROBE_OK ", JSON.stringify(measured))
	get_tree().quit()

func _shot(label: String, panel: Control) -> void:
	for frame: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var size: Vector2i = get_tree().root.size
	assert(Rect2(Vector2.ZERO, Vector2(size)).grow(1).encloses(panel.get_global_rect()), label)
	var close_button: Control = (player.get_node("FarmSettings") as TradeMenu).close_button
	assert(panel.get_global_rect().encloses(close_button.get_global_rect()), "Settings close button must stay visible")
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join("%s-%dx%d.png" % [label, size.x, size.y]))
