extends Node
## Real mixer, independent Music mute, and pause/resume validation.
const OUTPUT: String = "res://.godot/p2-audio-probe"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _peak(capture: AudioEffectCapture) -> float:
	var peak: float = 0.0
	for sample: Vector2 in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak

func _run() -> void:
	var world: FarmWorld = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	for node: Node in world.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	Sound.stop_all()
	var levels: Array[float] = [FarmUI.master_volume, FarmUI.music_volume, FarmUI.ambience_volume]
	FarmUI.master_volume = 1.0
	FarmUI.music_volume = 1.0
	FarmUI.ambience_volume = 1.0
	Sound.apply_volumes()
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	var voice: AudioStreamPlayer = world.atmosphere.music_voices[0]
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	var measured: Array[Dictionary] = []
	var ok: bool = true
	for key: StringName in FarmAtmosphere.CATALOG:
		voice.stop()
		await get_tree().create_timer(0.15).timeout
		capture.clear_buffer()
		voice.stream = world.atmosphere._loop(key)
		voice.bus = &"Music" if String(key).begins_with("music_") else &"Ambience"
		voice.volume_linear = 0.55
		voice.play()
		await get_tree().create_timer(0.6).timeout
		var peak: float = _peak(capture)
		ok = ok and peak > 0.00001
		measured.append({"event": String(key), "peak": peak})
	voice.stop()
	voice.bus = &"Music"
	voice.stream = world.atmosphere._loop(&"music_day")
	FarmUI.music_volume = 0.0
	Sound.apply_volumes()
	await get_tree().create_timer(0.15).timeout
	capture.clear_buffer()
	voice.play()
	await get_tree().create_timer(0.4).timeout
	var muted_peak: float = _peak(capture)
	ok = ok and muted_peak < 0.00001
	FarmUI.music_volume = 1.0
	Sound.apply_volumes()
	get_tree().paused = true
	await get_tree().create_timer(0.15).timeout
	var paused_at: float = voice.get_playback_position()
	await get_tree().create_timer(0.3).timeout
	var paused_end: float = voice.get_playback_position()
	get_tree().paused = false
	await get_tree().create_timer(0.3).timeout
	var resumed_at: float = voice.get_playback_position()
	var pause_ok: bool = absf(paused_end - paused_at) < 0.06 and resumed_at > paused_end + 0.1
	ok = ok and pause_ok
	voice.stop()
	AudioServer.remove_bus_effect(0, index)
	FarmUI.master_volume = levels[0]
	FarmUI.music_volume = levels[1]
	FarmUI.ambience_volume = levels[2]
	Sound.apply_volumes()
	var reference: WeakRef = weakref(voice)
	var save_unbound: bool = SaveManager.adapter == null
	world.queue_free()
	await get_tree().process_frame
	var freed: bool = reference.get_ref() == null
	ok = ok and freed and save_unbound
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file: FileAccess = FileAccess.open(OUTPUT.path_join("mixer_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "mixer_outputs": measured, "music_muted_peak": muted_peak, "pause_ok": pause_ok, "pause_positions": [paused_at, paused_end, resumed_at], "voices_freed": freed, "save_adapter_unbound": save_unbound}, "\t"))
	print("P2_AUDIO_PROBE_OK=", ok, " ", JSON.stringify(measured))
	get_tree().quit(0 if ok else 1)
