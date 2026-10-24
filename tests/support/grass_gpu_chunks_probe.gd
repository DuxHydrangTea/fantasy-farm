extends Node2D
## Native G2 image comparisons against ordinary sorted Sprite2D nodes.
var _directory: String
var _checks: int = 0
var _failures: Array[String] = []
var _world: Node2D
var _camera: Camera2D
var _field: GrassChunkField
var _references: Array[Node2D] = []
var _actors: Array[Node2D] = []
var _benchmarks: Array[Dictionary] = []
var _buffer_memory: Array[int] = []

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_directory = args[0] if not args.is_empty() else "user://grass-g2"
	DirAccess.make_dir_recursive_absolute(_directory)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size = Vector2i(256, 256)
	Engine.max_fps = 60
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		push_error(message)

func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func _sample(point: Vector2, scale_value: float = 4.0, tall: bool = true, z: int = 0) -> Dictionary:
	return {"type": 10, "transform": Transform2D(0.0, Vector2.ONE * scale_value, 0.0, point), "phase": 0.0, "tall": tall, "z_index": z}

func _setup(values: Array[Dictionary]) -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_camera = Camera2D.new()
	_camera.position = Vector2(128, 128)
	_world.add_child(_camera)
	_camera.force_update_scroll()
	_field = GrassChunkField.new()
	_field.samples = values
	_field.reserve_chunks = 0
	_field.wind_strength = 0.0
	_world.add_child(_field)
	_field.effect.set_shader_parameter(&"fixed_frame", 0)
	_field.set_process(false)
	for value: Dictionary in values:
		var holder: Node2D = Node2D.new()
		holder.transform = value.transform
		holder.z_index = int(value.get("z_index", 0))
		var sprite: Sprite2D = Sprite2D.new()
		var row: Dictionary = _field.catalog.source(int(value.type))
		sprite.texture = load(row.path)
		sprite.hframes = 8
		sprite.centered = false
		sprite.position = Vector2(-8, -float(row.root_y))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(sprite)
		_world.add_child(holder)
		holder.hide()
		_references.append(holder)

func _actor(point: Vector2, in_pen: bool) -> Node2D:
	var actor: Node2D = Node2D.new()
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-24, -90), Vector2(24, -90), Vector2(24, 8), Vector2(-24, 8)])
	body.color = Color(1, 0, 1)
	actor.add_child(body)
	if in_pen:
		var pen: AnimalPen = AnimalPen.new()
		pen.y_sort_enabled = true
		pen.position = Vector2(20, 31)
		_world.add_child(pen)
		pen.add_child(actor)
		actor.position = point - pen.position
	else:
		_world.add_child(actor)
		actor.position = point
	_actors.append(actor)
	return actor

func _compare(label: String) -> void:
	_camera.force_update_scroll()
	_field.update_view()
	_field.show()
	for holder: Node2D in _references:
		holder.hide()
	var actual: Image = await _capture()
	_field.hide()
	for holder: Node2D in _references:
		holder.show()
	var expected: Image = await _capture()
	var delta: float = float(actual.compute_image_metrics(expected, false).get("max", 255.0))
	_check(_has_pixels(expected), label + " contains visible reference pixels")
	_check(delta <= 1.0, label + " matches original sorted sprites; max delta=" + str(delta))
	if delta > 1.0:
		actual.save_png(_directory + "/failure-" + label + "-gpu.png")
		expected.save_png(_directory + "/failure-" + label + "-sprite.png")
	if label == "pen-between-rows":
		actual.save_png(_directory + "/sorted-pen.png")
	for holder: Node2D in _references:
		holder.hide()
	_field.show()

func _has_pixels(image: Image) -> bool:
	var bytes: PackedByteArray = image.get_data()
	for i: int in range(4, bytes.size(), 4):
		if bytes[i] != bytes[0] or bytes[i + 1] != bytes[1] or bytes[i + 2] != bytes[2]:
			return true
	return false

func _clear_world() -> void:
	_world.free()
	_references.clear()
	_actors.clear()

func _run() -> void:
	for nested: bool in [false, true]:
		for y: float in [124.0, 132.0]:
			_setup([_sample(Vector2(128, 128))])
			_actor(Vector2(128, y), nested)
			await _compare(("pen" if nested else "player") + "-foot-" + str(int(y)))
			_clear_world()
	_setup([_sample(Vector2(112, 100)), _sample(Vector2(144, 140))])
	_actor(Vector2(128, 120), true)
	await _compare("pen-between-rows")
	_clear_world()
	_setup([_sample(Vector2(128, 128))])
	_field.position = Vector2(8, 12)
	_field.scale = Vector2(1.25, 0.75)
	_references[0].transform = _field.transform * _references[0].transform
	_actor(Vector2(168, 112), true)
	await _compare("manager-transform")
	_clear_world()
	for z: int in [-1, 2]:
		_setup([_sample(Vector2(128, 128), 4, z > 0, z)])
		_actor(Vector2(128, 132 if z > 0 else 124), true)
		await _compare("z-" + str(z))
		_clear_world()
	await _edge_checks()
	await _lifecycle()
	await _benchmark()
	await _lab_controls()
	var report: Dictionary = {"checks": _checks, "failures": _failures, "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string, "benchmarks": _benchmarks,
		"mobile_tested": false, "actor_bending": false, "buffer_memory_bytes_rebuild_cycles": _buffer_memory}
	var file: FileAccess = FileAccess.open(_directory + "/g2-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GRASS_G2=" + JSON.stringify({"checks": _checks, "failures": _failures, "renderer": report.renderer}))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _edge_checks() -> void:
	_setup([_sample(Vector2(512, 128))])
	for z: float in [0.75, 1.0, 1.5]:
		_camera.zoom = Vector2.ONE * z
		_camera.position = Vector2(512, 128)
		await _compare("zoom-" + str(z))
	for center: Vector2 in [Vector2(372, 128), Vector2(652, 128), Vector2(512, -16), Vector2(512, 236)]:
		_camera.zoom = Vector2.ONE
		_camera.position = center
		await _compare("edge-" + str(int(center.x)) + "-" + str(int(center.y)))
	# Compare moving vertex bounds against the unchunked GPU reference at an edge.
	_camera.position = Vector2(372, 128)
	_camera.force_update_scroll()
	_field.set_wind(6)
	_field.effect.set_shader_parameter(&"use_test_time", true)
	_field.effect.set_shader_parameter(&"test_time", 1.25)
	_field.update_view()
	var moved: Image = await _capture()
	_field.hide()
	var full: GrassField = GrassField.new()
	full.samples = [_sample(Vector2(512, 128))]
	_world.add_child(full)
	full.set_wind(6)
	full.set_test_time(1.25)
	full.effect.set_shader_parameter(&"fixed_frame", 0)
	_check(moved.get_data() == (await _capture()).get_data(), "Wind at chunk/view boundary matches full GPU batch")
	_clear_world()

func _lifecycle() -> void:
	_setup([_sample(Vector2(128, 128))])
	_field.update_view()
	var visible: Image = await _capture()
	_field.hide()
	var hidden: Image = await _capture()
	_check(visible.get_data() != hidden.get_data(), "Hiding manager hides sibling RIDs")
	_field.show()
	_check(visible.get_data() == (await _capture()).get_data(), "Showing manager restores sibling RIDs")
	_field.set_enabled(false)
	_check(hidden.get_data() == (await _capture()).get_data(), "Disabling manager hides all grass")
	_field.set_enabled(true)
	_check(visible.get_data() == (await _capture()).get_data(), "Enabling restores cached grass")
	for cycle: int in range(20):
		_field.rebuild()
		await RenderingServer.frame_post_draw
		_buffer_memory.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED))
		_check(_field.renderer.allocated_leaves - _field.renderer.freed_leaves == 1, "Exactly one live row after rebuild cycle " + str(cycle))
	_world.remove_child(_field)
	_check(_field.renderer.allocated_leaves == _field.renderer.freed_leaves, "Exit frees all owned CanvasItem RIDs")
	_check(hidden.get_data() == (await _capture()).get_data(), "Exit leaves no orphan grass drawing")
	_world.add_child(_field)
	_field.effect.set_shader_parameter(&"fixed_frame", 0)
	_check(visible.get_data() == (await _capture()).get_data(), "Reenter rebuilds drawing")
	_clear_world()

func _dataset(extra: int) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for i: int in range(4096 + extra):
		var far: bool = i >= 4096
		var x: int = i % 128
		var y: int = floori(float(i if not far else i - 4096) / 128.0)
		values.append({"type": i % 18, "transform": Transform2D(0.0, Vector2(x * 16 + (10000 if far else 0), y * 16)),
			"phase": float(i % 17) / 17.0, "tall": y % 4 != 0, "z_index": 0 if y % 4 != 0 else -1})
	return values

func _benchmark() -> void:
	get_tree().root.size = Vector2i(640, 480)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for size_pixels: int in [256, 512]:
		var small: Dictionary
		for extra: int in [0, 61440]:
			_world = Node2D.new()
			_world.y_sort_enabled = true
			add_child(_world)
			_camera = Camera2D.new()
			_camera.position = Vector2(320, 240)
			_world.add_child(_camera)
			_field = GrassChunkField.new()
			_field.samples = _dataset(extra)
			_field.chunk_size = size_pixels
			_world.add_child(_field)
			var raw_gpu: Array[float] = []
			var raw_cpu: Array[float] = []
			var raw_wall: Array[float] = []
			for i: int in range(60):
				await RenderingServer.frame_post_draw
			var queries: int = _field.renderer.lookups
			var built: int = _field.renderer.builds
			var previous: int = Time.get_ticks_usec()
			for i: int in range(120):
				await RenderingServer.frame_post_draw
				var now: int = Time.get_ticks_usec()
				raw_wall.append(float(now - previous) / 1000.0)
				previous = now
				raw_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
				raw_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
			var measured: Dictionary = {"chunk_size": size_pixels, "dataset_instances": 4096 + extra, "grass_nodes": 1,
				"cache": _field.renderer.stats(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"render_cpu_ms": _summary(raw_cpu), "gpu_ms": _summary(raw_gpu), "capped_frame_ms": _summary(raw_wall),
				"raw_samples": {"gpu_ms": raw_gpu, "render_cpu_ms": raw_cpu, "frame_interval_ms": raw_wall}, "fps_cap": 60, "viewport": [640, 480]}
			_check(_field.renderer.lookups == queries and _field.renderer.builds == built, "Stationary view does not query/rebuild " + str(size_pixels) + "/" + str(extra))
			_check(_field.get_child_count() == 0, "One feature node for dataset " + str(4096 + extra))
			if extra == 0:
				small = measured
			else:
				_check(measured.cache.live_leaves == small.cache.live_leaves and measured.cache.resident_instances == small.cache.resident_instances,
					"Offscreen 61440 instances do not add live batches/buffers " + str(size_pixels))
			_benchmarks.append(measured)
			_clear_world()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)

func _summary(values: Array[float]) -> Dictionary:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return {"p50": sorted[floori(float(sorted.size() - 1) * 0.5)], "p95": sorted[floori(float(sorted.size() - 1) * 0.95)], "max": sorted[-1]}

func _lab_controls() -> void:
	var lab: Node2D = load("res://tests/support/grass_gpu_chunks_poc.tscn").instantiate() as Node2D
	add_child(lab)
	await _capture()
	_check(lab.field.index.total_instances == 8192 and lab.field.get_child_count() == 0, "Lab has 8192 indexed tufts and one feature node")
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_C
	lab._unhandled_input(key)
	_check(lab.field.chunk_size == 256, "Lab switches chunk size from measured desktop default 512")
	key.keycode = KEY_H
	lab._unhandled_input(key)
	_check(not lab.field.visible and not lab.field.is_processing(), "Lab hides and stops manager updates")
	lab._unhandled_input(key)
	key.keycode = KEY_R
	var before: int = lab.field.index_builds
	lab._unhandled_input(key)
	_check(lab.field.index_builds == before + 1 and lab.field.renderer.last_error == "", "Lab reload restores chunks")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	lab._unhandled_input(wheel)
	_check(lab.camera.zoom == Vector2(2.75, 2.75), "Lab zoom control")
	var previous: Vector2 = lab.player.position
	Input.action_press(&"ui_right")
	await get_tree().create_timer(0.1).timeout
	Input.action_release(&"ui_right")
	_check(lab.player.position.x > previous.x, "Lab movement input changes actor/camera position")
	key.keycode = KEY_C
	lab._unhandled_input(key)
	await get_tree().create_timer(0.3).timeout
	(await _capture()).save_png(_directory + "/g2-lab.png")
	lab.free()
