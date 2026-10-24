extends Node2D
## Isolated native baseline. Never binds SaveManager, never reads a player save.
const WARMUP_FRAMES: int = 120
const SAMPLE_FRAMES: int = 240
var _directory: String

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_directory = args[0] if not args.is_empty() else "user://grass-baseline"
	DirAccess.make_dir_recursive_absolute(_directory)
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var reports: Array[Dictionary] = []
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	get_tree().root.size = Vector2i(1280, 720)
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.player.global_position = Vector2(888, 536)
	await get_tree().create_timer(0.5).timeout
	var baseline: Dictionary = await _sample("main_world_fresh_no_save")
	baseline["scope"] = "Fresh bootstrap, no player save, no populated herd; desktop baseline only"
	baseline["world_nodes"] = _nodes(world)
	baseline["flower_garden_locked"] = not world.starter_content.flower_garden_unlocked
	baseline["land_columns"] = world.land.state.unlocked_columns
	baseline["weather"] = "SUNNY; debug noon; stationary camera/player"
	reports.append(baseline)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_directory + "/main-baseline.png")
	world.free()
	await get_tree().process_frame
	get_tree().root.content_scale_size = Vector2i(640, 520)
	get_tree().root.size = Vector2i(1024, 832)
	var field: GrassField = GrassField.new()
	field.position = Vector2(104, 82)
	add_child(field)
	for variant: String in ["static", "wind", "wind_animation"]:
		field.set_wind(0.0 if variant == "static" else 0.85)
		field.set_animation(variant == "wind_animation")
		var measured: Dictionary = await _sample("grass_324_" + variant)
		measured["grass_nodes"] = _nodes(field)
		measured["grass_instances"] = field.renderer.instances.instance_count
		measured["grass_cpu_process"] = field.is_processing()
		measured["grass_cpu_physics"] = field.is_physics_processing()
		measured["phase"] = "G1; no interactions or chunks yet"
		reports.append(measured)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_directory + "/poc-324.png")
	field.free()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	var result: Dictionary = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "os": OS.get_name(), "fps_cap": 60, "warmup_frames": WARMUP_FRAMES,
		"sample_frames": SAMPLE_FRAMES, "device_class": "native desktop", "mobile_measured": false, "reports": reports}
	var file: FileAccess = FileAccess.open(_directory + "/baseline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("GRASS_BASELINE=" + JSON.stringify(result))
	get_tree().quit()

func _sample(label: String) -> Dictionary:
	for index: int in range(WARMUP_FRAMES):
		await RenderingServer.frame_post_draw
	var wall_ms: Array[float] = []
	var cpu_ms: Array[float] = []
	var gpu_ms: Array[float] = []
	var render_cpu_ms: Array[float] = []
	var calls: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for index: int in range(SAMPLE_FRAMES):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		wall_ms.append(float(now - previous) / 1000.0)
		previous = now
		cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		calls.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	return {"case": label, "frame_interval_ms_includes_60fps_cap": _summary(wall_ms), "process_cpu_ms": _summary(cpu_ms),
		"raw_samples": {"frame_interval_ms": wall_ms, "process_cpu_ms": cpu_ms, "render_cpu_ms": render_cpu_ms, "gpu_ms": gpu_ms, "draw_calls": calls},
		"render_cpu_ms": _summary(render_cpu_ms), "gpu_ms": _summary(gpu_ms) if gpu_ms.any(func(value: float) -> bool: return value > 0.0) else null,
		"gpu_timer_note": "Null means unavailable/zero, never inferred from FPS", "draw_calls": _summary(calls),
		"process_timer_note": "Global Performance.TIME_PROCESS is sampled, may repeat between monitor updates; not an isolated grass CPU cost",
		"video_memory_bytes_global_includes_cached_resources": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"scene_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "window_size": [get_tree().root.size.x, get_tree().root.size.y]}

func _summary(values: Array[float]) -> Dictionary:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return {"min": sorted[0], "p50": sorted[floori(float(sorted.size() - 1) * 0.50)],
		"p95": sorted[floori(float(sorted.size() - 1) * 0.95)], "p99": sorted[floori(float(sorted.size() - 1) * 0.99)], "max": sorted[-1]}

func _nodes(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _nodes(child)
	return total
