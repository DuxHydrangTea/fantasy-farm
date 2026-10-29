extends Node
## Isolated startup acceptance probe; enabled only by benchmark_startup_load.py.
var _options: Dictionary = {}
var _began: int = Time.get_ticks_usec()
var _last: int = _began
var _gaps: Array[float] = []
var _first_loading_ms: float = -1.0
var _finishing: bool = false
var _slow_samples: Array[Dictionary] = []
var _loading_ui_ok: bool = false
var _loading_draw_ms: float = -1.0

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(0, args.size() - 1, 2):
		_options[args[index]] = args[index + 1]
	var target: float = float(_options["--target"])
	TimeManager.clock_source = func() -> float: return target
	TimeManager._last_timestamp = target
	TimeManager.set_process(false)

func _process(_delta: float) -> void:
	var stamp: int = Time.get_ticks_usec()
	var gap_ms: float = float(stamp - _last) / 1000.0
	_gaps.append(gap_ms)
	if gap_ms > 250.0 and _slow_samples.size() < 20 and DisplayServer.get_name() != "headless":
		_slow_samples.append({"at_ms": float(stamp - _began) / 1000.0, "gap_ms": gap_ms, "focused": DisplayServer.window_is_focused(), "window_mode": DisplayServer.window_get_mode(), "max_fps": Engine.max_fps, "low_processor_usage": OS.low_processor_usage_mode})
	_last = stamp
	var scene: Node = get_tree().current_scene
	if _first_loading_ms < 0.0 and scene != null and scene.name == &"LoadingScreen":
		_first_loading_ms = float(stamp - _began) / 1000.0
		_capture_loading.call_deferred()
	if not _finishing and SaveManager.writes_enabled and not SaveManager.busy:
		_finishing = true
		_finish.call_deferred()

func _capture_loading() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.name != &"LoadingScreen":
		return
	var label: Label = scene.get_node("Center/Column/Status") as Label
	var bar: ProgressBar = scene.get_node("Center/Column/Progress") as ProgressBar
	var bounds: Rect2 = get_viewport().get_visible_rect()
	_loading_ui_ok = label.size.x > 0 and label.size.y > 0 and bar.size.x > 0 and bar.size.y > 0 and bounds.encloses(label.get_global_rect()) and bounds.encloses(bar.get_global_rect()) and not label.get_global_rect().intersects(bar.get_global_rect())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_loading_draw_ms = float(Time.get_ticks_usec() - _began) / 1000.0
		get_viewport().get_texture().get_image().save_png(String(_options["--result"]) + ".loading.png")

func _finish() -> void:
	var total_ms: float = float(Time.get_ticks_usec() - _began) / 1000.0
	var world: FarmWorld = get_tree().current_scene as FarmWorld
	var ok: bool = _loading_ui_ok and world != null and is_equal_approx(world.workers.simulated_at, float(_options["--target"]))
	_gaps.sort()
	var result: Dictionary = {"ok": ok, "startup_ms": total_ms, "first_loading_process_ms": _first_loading_ms,
		"frame_gap_p95_ms": _gaps[ceili(float(_gaps.size()) * 0.95) - 1], "frame_gap_max_ms": _gaps.back(),
		"slow_frame_samples": _slow_samples, "loading_ui_ok": _loading_ui_ok, "first_loading_post_draw_ms": _loading_draw_ms,
		"frames": _gaps.size(), "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"window_size": str(DisplayServer.window_get_size()), "revision": SaveManager.revision,
		"note": "Startup measured from probe autoload initialization. First loading process is not a measured display scanout."}
	result["input_ready"] = world != null and world.process_mode != Node.PROCESS_MODE_DISABLED and world.tool_upgrades.profile_ready
	if DisplayServer.get_name() != "headless":
		var moved: bool = false
		for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down"]:
			var origin: Vector2 = world.player.global_position
			Input.action_press(action)
			for _frame: int in range(12):
				await get_tree().physics_frame
			Input.action_release(action)
			if world.player.global_position.distance_to(origin) > 1.0:
				moved = true
				break
		result["player_moved_after_load"] = moved
		ok = ok and moved and bool(result.input_ready)
		result.ok = ok
		await RenderingServer.frame_post_draw
		var screenshot: Image = get_viewport().get_texture().get_image()
		screenshot.save_png(String(_options["--result"]) + ".png")
	var file: FileAccess = FileAccess.open(String(_options["--result"]), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	# Quit before the first autosave; the launcher also discards isolated userdata.
	get_tree().quit(0 if ok else 1)
