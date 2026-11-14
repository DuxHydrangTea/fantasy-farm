extends Node
## Real mixer check; run with --audio-driver Dummy, without --headless.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: FarmWorld = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	for node: Node in world.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	var previous: Array[float] = [FarmUI.master_volume, FarmUI.ambience_volume]
	FarmUI.master_volume = 1.0
	FarmUI.ambience_volume = 1.0
	Sound.apply_volumes()
	var voice: AudioStreamPlayer2D = world.soundscape.voices[0]
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	voice.stream = FarmSound.P1_CATALOG[&"animal_cow"][0] as AudioStream
	var measurements: Array[Dictionary] = []
	for distance: float in [20.0, 180.0, FarmSoundscape.RADIUS]:
		voice.stop()
		await get_tree().create_timer(0.15).timeout
		capture.clear_buffer()
		if world.soundscape._place(voice, world.player.global_position + Vector2(distance, 0), FarmSoundscape.CALL_VOLUME_DB):
			voice.play()
		await get_tree().create_timer(0.7).timeout
		var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		var peak: float = 0.0
		for sample: Vector2 in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		measurements.append({"distance": distance, "peak": peak, "frames": samples.size()})
	voice.stop()
	AudioServer.remove_bus_effect(0, effect_index)
	FarmUI.master_volume = previous[0]
	FarmUI.ambience_volume = previous[1]
	Sound.apply_volumes()
	var ok: bool = float(measurements[0].peak) > 0.0001 and float(measurements[1].peak) < float(measurements[0].peak) * 0.3 and float(measurements[1].peak) > 0.0 and float(measurements[2].peak) < 0.00001
	DirAccess.make_dir_recursive_absolute("res://.godot/p1-audio-probe")
	var file: FileAccess = FileAccess.open("res://.godot/p1-audio-probe/mixer_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "measurements": measurements}, "\t"))
	print("P1_MIXER ", JSON.stringify(measurements), " OK=", ok)
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
