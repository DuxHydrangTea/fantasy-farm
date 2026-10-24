extends Node2D
## Pixel-level native render checks. Run on BOTH gl_compatibility and forward_plus.
var field: GrassField
var reference: Sprite2D
var checks: int = 0
var failures: Array[String] = []
var _directory: String
var _backend: String
var _worst_error: float = 0.0
var _edge_cases: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(256, 256)
	_backend = RenderingServer.get_current_rendering_method()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_directory = args[0] if args.size() > 0 else "user://grass-probe"
	DirAccess.make_dir_recursive_absolute(_directory)
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Image = get_viewport().get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result

func _run() -> void:
	field = GrassField.new()
	field.samples = [{"type": 0, "transform": Transform2D.IDENTITY, "phase": 0.0}]
	add_child(field)
	field.set_wind(0)
	field.set_test_time(0)
	reference = Sprite2D.new()
	reference.centered = false
	reference.hframes = 8
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(reference)
	_check(field.get_child_count() == 0, "No per-tuft nodes")
	_check(not field.is_processing() and not field.is_physics_processing(), "Grass has no CPU tick")
	# Every original type and every original frame, rendered against Sprite2D.
	for type: int in range(field.catalog.size()):
		for frame: int in range(8):
			await _compare_source(type, frame, Transform2D(0.0, Vector2(4, 4), 0.0, Vector2(128, 128)), Transform2D.IDENTITY)
			if failures.size() >= 6:
				_finish()
				return
	for type: int in [0, 10, 15]:
		for scale_value: Vector2 in [Vector2(-3.25, 2.5), Vector2(2.75, -3.0)]:
			await _compare_source(type, 3, Transform2D(0.23, scale_value, 0.0, Vector2(128.25, 128.5)), Transform2D(0.0, Vector2(7.5, -3.5)), true)
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(128, 128)
	add_child(camera)
	for zoom_value: float in [1.25, 2.0]:
		camera.zoom = Vector2.ONE * zoom_value
		for type: int in [0, 10, 15]:
			await _compare_source(type, 5, Transform2D(0.0, Vector2(4, 4), 0.0, Vector2(128, 128)), Transform2D.IDENTITY)
	camera.free()
	reference.hide()
	await _anchors_and_time()
	# Verify shader INSTANCE_CUSTOM/transform is independent for multiple roots.
	field.transform = Transform2D.IDENTITY
	field.set_samples([{"type": 0, "transform": Transform2D(0.0, Vector2(6, 6), 0.0, Vector2(56, 128)), "phase": 0.0}, {"type": 15, "transform": Transform2D(0.0, Vector2(6, 6), 0.0, Vector2(184, 128)), "phase": 0.0}])
	field.effect.set_shader_parameter(&"debug_anchor_only", true)
	field.set_wind(6)
	field.set_test_time(1.25)
	var roots: Dictionary = _magenta(await _capture())
	_check(int(roots.count) > 0 and float(roots.min_x) < 64 and float(roots.max_x) > 176, "Distinct instance roots, no shared node pivot")
	field.free()
	reference.free()
	await _poc_controls()
	_finish()

func _poc_controls() -> void:
	var lab: Node2D = load("res://tests/support/grass_gpu_poc.tscn").instantiate() as Node2D
	add_child(lab)
	await _capture()
	_check(lab.field.renderer.instances.instance_count == 324, "Standalone POC builds 324 tufts")
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	for code: Key in [KEY_W, KEY_A, KEY_F, KEY_P, KEY_T]:
		key.keycode = code
		lab._unhandled_input(key)
	_check(lab.field.wind_strength == 0.0 and not lab.field.animate_frames, "POC W/A controls")
	_check(int(lab.field.effect.get_shader_parameter(&"fixed_frame")) == 0, "POC forced atlas frame")
	_check(get_tree().paused and Engine.time_scale == 0.0, "POC pause/time-scale controls")
	for code: Key in [KEY_W, KEY_A, KEY_P, KEY_T]:
		key.keycode = code
		lab._unhandled_input(key)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	lab._unhandled_input(wheel)
	_check(lab.camera.zoom == Vector2(1.25, 1.25), "POC fractional camera zoom control")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	lab._unhandled_input(wheel)
	key.keycode = KEY_F
	for index: int in range(8):
		lab._unhandled_input(key)
	_check(lab.field.is_processing() == false and lab.field.get_child_count() == 0, "POC controls preserve one grass node without CPU tick")
	(await _capture()).save_png(_directory + "/poc-controls.png")
	lab.free()
	_check(not get_tree().paused and Engine.time_scale == 1.0, "POC exit restores pause/time scale")

func _compare_source(type: int, frame: int, parent_pose: Transform2D, instance_pose: Transform2D, fractional_rotation: bool = false) -> void:
	field.transform = parent_pose
	field.set_samples([{"type": type, "transform": instance_pose, "phase": 0.0}])
	field.effect.set_shader_parameter(&"fixed_frame", frame)
	field.show()
	reference.hide()
	var actual: Image = await _capture()
	field.hide()
	var row: Dictionary = field.catalog.source(type)
	reference.texture = load(row.path) as Texture2D
	reference.frame = frame
	reference.transform = parent_pose * instance_pose * Transform2D(0.0, Vector2(-8, -float(row.root_y)))
	reference.show()
	var expected: Image = await _capture()
	var error: float = float(actual.compute_image_metrics(expected, false).get("max", 1.0))
	_worst_error = maxf(_worst_error, error)
	var edge_pixels: int = 0
	if error > 1.0 and fractional_rotation:
		var a: PackedByteArray = actual.get_data()
		var b: PackedByteArray = expected.get_data()
		for index: int in range(0, a.size(), 4):
			if a[index] != b[index] or a[index + 1] != b[index + 1] or a[index + 2] != b[index + 2] or a[index + 3] != b[index + 3]:
				edge_pixels += 1
		_edge_cases.append({"type": type, "frame": frame, "different_pixels": edge_pixels, "max_channel_delta_255": error})
	# Arbitrary rotated/fractional transforms can resolve ONE exact nearest-texel
	# boundary differently after float32 matrix regrouping. Record, don't hide it.
	var matches: bool = error <= 1.0 or (fractional_rotation and edge_pixels == 1)
	_check(matches, "Sprite fidelity type %d frame %d max_channel_delta %.6f edge_pixels %d" % [type, frame, error, edge_pixels])
	if not matches and failures.size() <= 3:
		actual.save_png(_directory + "/failure-%d-%d-gpu.png" % [type, frame])
		expected.save_png(_directory + "/failure-%d-%d-original.png" % [type, frame])

func _anchors_and_time() -> void:
	field.show()
	field.transform = Transform2D(0.0, Vector2(6, 6), 0.0, Vector2(128, 128))
	field.effect.set_shader_parameter(&"debug_anchor_only", true)
	for type: int in [0, 10, 15, 17]:
		field.set_samples([{"type": type, "transform": Transform2D.IDENTITY, "phase": 0.0}])
		field.set_wind(0)
		var base: Dictionary = _magenta(await _capture())
		_check(int(base.count) > 0, "Anchor strip is visible for source %d" % type)
		for time: float in [0.0, 1.25, 4.2]:
			field.set_wind(6)
			field.set_test_time(time)
			var moved: Dictionary = _magenta(await _capture())
			_check(int(moved.count) > 0 and absf(float(moved.x) - float(base.x)) <= 1.0 and absf(float(moved.y) - float(base.y)) <= 1.0, "Pinned opaque ground type %d time %.2f" % [type, time])
	field.effect.set_shader_parameter(&"debug_anchor_only", false)
	field.effect.set_shader_parameter(&"fixed_frame", 2)
	field.set_test_time(0)
	var wind_a: Image = await _capture()
	field.set_test_time(1.25)
	var wind_b: Image = await _capture()
	_check(wind_a.get_data() != wind_b.get_data(), "Wind changes actual rendered pixels")
	wind_b.save_png(_directory + "/wind.png")
	field.set_test_time(0)
	var before_rollover: Image = await _capture()
	field.set_test_time(3600)
	_check(before_rollover.get_data() == (await _capture()).get_data(), "5s/9s wind periods survive the default TIME rollover")
	field.set_wind(0)
	field.effect.set_shader_parameter(&"fixed_frame", -1)
	field.set_animation(true)
	field.set_test_time(0)
	var frame_a: Image = await _capture()
	field.set_test_time(0.125)
	_check(frame_a.get_data() != (await _capture()).get_data(), "GPU changes the atlas frame")
	field.set_test_time(1.0)
	_check(frame_a.get_data() == (await _capture()).get_data(), "Eight GPU frames loop without sampling the next row")
	field.set_wind(6)
	field.set_test_time(0, false)
	get_tree().paused = true
	var paused_a: Image = await _capture()
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(paused_a.get_data() != (await _capture()).get_data(), "Engine TIME continues during scene pause, like existing crop wind")
	get_tree().paused = false
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.1, true, false, true).timeout
	var frozen: Image = await _capture()
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(frozen.get_data() == (await _capture()).get_data(), "Engine time_scale zero freezes wind/frame animation")
	Engine.time_scale = 1.0
	# No hidden scene nodes are created during buffer rebuilds.
	for index: int in range(30):
		field.set_samples([{"type": index % 18, "transform": Transform2D.IDENTITY, "phase": 0.0}])
	_check(field.get_child_count() == 0 and field.renderer.instances.instance_count == 1, "Rebuilds keep one node and one batch")

func _magenta(image: Image) -> Dictionary:
	var bytes: PackedByteArray = image.get_data()
	var total_x: float = 0.0
	var total_y: float = 0.0
	var count: int = 0
	var min_x: int = image.get_width()
	var max_x: int = 0
	for index: int in range(0, bytes.size(), 4):
		if bytes[index] > 240 and bytes[index + 1] < 8 and bytes[index + 2] > 240:
			var pixel: int = floori(float(index) / 4.0)
			var x: int = pixel % image.get_width()
			total_x += x
			total_y += floori(float(pixel) / float(image.get_width()))
			count += 1
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	return {"x": total_x / maxi(1, count), "y": total_y / maxi(1, count), "count": count, "min_x": min_x, "max_x": max_x}

func _finish() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var report: Dictionary = {"renderer": _backend, "checks": checks, "failures": failures, "max_channel_delta_255": _worst_error, "fractional_rotation_edge_cases": _edge_cases,
		"gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string}
	var file: FileAccess = FileAccess.open(_directory + "/render-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GRASS_GPU_PROBE=" + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
