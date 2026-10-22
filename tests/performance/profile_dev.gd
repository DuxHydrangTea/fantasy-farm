extends SceneTree
## Run directly from current dev source; never exported or attached to gameplay.
## Config path is the first argument following --. Save data must be isolated.

var config: Dictionary = {}
var report: Dictionary = {}
var world: Node2D
var save_manager: Node
var origin: Vector2
var zoom_component: Node
var hotbar: Node
var viewport_rid: RID
var save_probe_result: Dictionary = {}
var save_probe_ms: float = 0.0
var save_probe_done: bool = false
var save_rejections: Array = []
var polling_states: Dictionary = {}

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Pass a benchmark config JSON after --")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not parsed is Dictionary:
		quit(2)
		return
	config = parsed
	_run.call_deferred()

func _run() -> void:
	seed(20261022)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	if bool(config.get("isolate_benchmark", false)):
		# Keep desktop input and tooling traffic out of the repeatable workload.
		root.gui_disable_input = true
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
		OS.low_processor_usage_mode = false
		var mcp: Node = root.get_node_or_null("MCPRuntimeServer")
		if mcp != null:
			mcp.set_process(false)
	if config.has("clock_start"):
		var clock: Node = root.get_node("TimeManager")
		var epoch: float = float(config["clock_start"])
		var elapsed_start: int = Time.get_ticks_usec()
		clock.set("_last_timestamp", epoch)
		clock.set("clock_source", func() -> float: return epoch + float(Time.get_ticks_usec() - elapsed_start) / 1000000.0)
	save_manager = root.get_node("SaveManager")
	var packed: PackedScene = load("res://world/main_world.tscn") as PackedScene
	world = packed.instantiate() as Node2D
	if config.has("butterfly_seed"):
		world.get_node("FarmLandscape/ButterflySwarm").set("random_seed", int(config["butterfly_seed"]))
	root.add_child(world)
	current_scene = world
	await create_timer(5.0).timeout
	while save_manager.busy:
		await process_frame
	if not save_manager.writes_enabled:
		push_error("Profile did not load successfully")
		quit(2)
		return
	if bool(config.get("verify_save_only", false)):
		var revision: int = int(save_manager.revision)
		var saved: Dictionary = await save_manager.save_game()
		var loaded: Dictionary = await save_manager.repository.read_profile(save_manager.profile_id)
		var backup: Dictionary = save_manager.repository._read(save_manager.repository.path(save_manager.profile_id) + ".bak", save_manager.profile_id)
		report = {"functional_check_only": true, "save_ok": saved.ok,
			"save_error": saved.get("error", ""), "revision_before": revision,
			"revision_after": save_manager.revision, "read_ok": loaded.ok,
			"backup_ok": backup.ok, "world_hives": world.apiary.hives.size()}
		if loaded.ok:
			report["saved_hives"] = loaded.snapshot.beehives.size()
			report["read_revision"] = loaded.snapshot.revision
		if backup.ok:
			report["backup_revision"] = backup.snapshot.revision
		report["completed"] = true
		_write_report()
		quit(0 if saved.ok and loaded.ok and backup.ok else 1)
		return
	origin = world.player.global_position
	zoom_component = _find_script(world, "res://components/camera_zoom_component.gd")
	hotbar = _find_script(world, "res://components/hotbar_ui.gd")
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var butterflies: Node = world.get_node_or_null("FarmLandscape/ButterflySwarm")
	report = {
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"window_size": str(DisplayServer.window_get_size()),
		"viewport_visible_rect": str(root.get_visible_rect()),
		"zoom": str(world.player.camera.zoom),
		"max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"save_revision_loaded": save_manager.revision,
		"butterflies": butterflies.get_child_count() if butterflies != null else 0,
		"zoom_component_found": zoom_component != null,
		"hotbar_found": hotbar != null,
		"isolate_benchmark": bool(config.get("isolate_benchmark", false)),
		"low_processor_mode": OS.low_processor_usage_mode,
		"samples": [],
		"config": config,
	}
	var scenarios: Array = config.get("scenarios", ["idle", "walking", "rain", "saving", "idle_polling_paused"])
	for trial: int in range(int(config.get("rounds", 2))):
		# Reverse order on alternating rounds to reveal warmup/order effects.
		var order: Array = scenarios.duplicate()
		if trial % 2 == 1:
			order.reverse()
		for scenario: String in order:
			_release_actions()
			world.player.global_position = origin
			world.weather.set_weather(1 if scenario == "rain" else 0)
			_set_polling(true)
			save_manager.set("_elapsed", 0.0)
			await create_timer(float(config.get("warmup_seconds", 3.0))).timeout
			if scenario == "idle_polling_paused":
				_set_polling(false)
			var result: Dictionary = await _measure(scenario, trial + 1)
			report["samples"].append(result)
			_set_polling(true)
			_write_report()
			print("[DEV_PROFILE] ", JSON.stringify(result))
			if trial == 0 and scenario in ["idle", "rain"]:
				await RenderingServer.frame_post_draw
				var image: Image = root.get_texture().get_image()
				image.save_png(str(config["output"]).get_base_dir().path_join(scenario + ".png"))
	_release_actions()
	report["completed"] = true
	_write_report()
	quit(0)

func _measure(scenario: String, trial: int) -> Dictionary:
	var metrics: Dictionary = {}
	for metric: String in ["frame_ms", "process_ms", "physics_ms", "render_cpu_ms", "render_gpu_ms", "render_setup_ms", "draw_calls", "static_mib", "video_mib", "nodes"]:
		metrics[metric] = []
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var duration: float = float(config.get("seconds", 10.0))
	var direction: int = -1
	var saved: bool = false
	save_probe_result = {}
	save_probe_ms = 0.0
	save_probe_done = false
	save_rejections = []
	var initial_position: Vector2 = world.player.global_position
	var distance_travelled: float = 0.0
	var last_position: Vector2 = initial_position
	while float(Time.get_ticks_usec() - started) / 1000000.0 < duration:
		var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
		if scenario == "walking":
			var next_direction: int = int(elapsed / 2.0) % 4
			if next_direction != direction:
				_release_actions()
				direction = next_direction
				Input.action_press([&"move_left", &"move_up", &"move_right", &"move_down"][direction])
		if scenario == "saving" and not saved and elapsed >= duration / 2.0:
			saved = true
			_save_probe()
		await process_frame
		var now: int = Time.get_ticks_usec()
		metrics["frame_ms"].append(float(now - previous) / 1000.0)
		previous = now
		metrics["process_ms"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		metrics["physics_ms"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		metrics["render_cpu_ms"].append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		metrics["render_gpu_ms"].append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		metrics["render_setup_ms"].append(RenderingServer.get_frame_setup_time_cpu())
		metrics["draw_calls"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		metrics["static_mib"].append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		metrics["video_mib"].append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		metrics["nodes"].append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		distance_travelled += world.player.global_position.distance_to(last_position)
		last_position = world.player.global_position
	_release_actions()
	var summary: Dictionary = {}
	for metric: String in metrics:
		summary[metric] = _stats(metrics[metric])
	var seconds: float = float(Time.get_ticks_usec() - started) / 1000000.0
	return {"scenario": scenario, "trial": trial, "seconds": seconds,
		"fps": float(metrics["frame_ms"].size()) / seconds,
		"frames_over_33ms": metrics["frame_ms"].filter(func(value: float) -> bool: return value > 33.333).size(),
		"frames_over_50ms": metrics["frame_ms"].filter(func(value: float) -> bool: return value > 50.0).size(),
		"distance_travelled": distance_travelled, "save_wall_ms": save_probe_ms,
		"save_ok": save_probe_result.get("ok", false) if saved else null,
		"save_completed": save_probe_done if saved else null,
		"save_error": str(save_probe_result.get("error", "")),
		"save_code": str(save_probe_result.get("code", "")),
		"save_rejected_types": save_rejections,
		"window_mode": DisplayServer.window_get_mode(),
		"window_focused": DisplayServer.window_is_focused(),
		"stats": summary}

func _save_probe() -> void:
	var started: int = Time.get_ticks_usec()
	save_probe_result = await save_manager.save_game()
	save_probe_ms = float(Time.get_ticks_usec() - started) / 1000.0
	save_probe_done = true
	if not bool(save_probe_result.get("ok", false)):
		var snapshot: Dictionary = save_manager.adapter.capture(save_manager.profile_id, save_manager.revision + 1, Time.get_unix_time_from_system())
		var schema: Script = load("res://persistence/save_schema.gd") as Script
		var checked: Dictionary = schema.validate(snapshot, save_manager.catalog)
		if bool(checked.get("ok", false)):
			_find_nonprimitive(checked["snapshot"], "$", 0)

func _find_nonprimitive(value: Variant, path: String, depth: int) -> void:
	if save_rejections.size() >= 10:
		return
	if depth > 64:
		save_rejections.append({"path": path, "type": "depth_limit"})
	elif value is Dictionary:
		for key: Variant in value:
			if not key is String:
				save_rejections.append({"path": path + "." + str(key), "type": "dictionary_key:" + type_string(typeof(key))})
			_find_nonprimitive(value[key], path + "." + str(key), depth + 1)
	elif value is Array:
		for index: int in range(value.size()):
			_find_nonprimitive(value[index], path + "[%d]" % index, depth + 1)
	elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		save_rejections.append({"path": path, "type": type_string(typeof(value))})

func _stats(values: Array) -> Dictionary:
	values.sort()
	var count: int = values.size()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"samples": count, "avg": total / maxi(count, 1),
		"p50": values[clampi(ceili(count * 0.5) - 1, 0, count - 1)],
		"p95": values[clampi(ceili(count * 0.95) - 1, 0, count - 1)],
		"p99": values[clampi(ceili(count * 0.99) - 1, 0, count - 1)],
		"min": values[0], "max": values[count - 1]}

func _set_polling(enabled: bool) -> void:
	if enabled:
		for target: Node in polling_states:
			target.set_process(bool(polling_states[target]))
		polling_states.clear()
	else:
		for target: Node in [world.weather.effects, zoom_component, hotbar]:
			if target != null:
				polling_states[target] = target.is_processing()
				target.set_process(false)

func _release_actions() -> void:
	for action: StringName in [&"move_left", &"move_up", &"move_right", &"move_down"]:
		Input.action_release(action)

func _find_script(node: Node, path: String) -> Node:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path == path:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_script(child, path)
		if found != null:
			return found
	return null

func _write_report() -> void:
	var path: String = str(config["output"])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
