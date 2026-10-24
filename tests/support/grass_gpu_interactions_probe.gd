extends "res://tests/support/grass_gpu_chunks_probe.gd"
## G3 native proof, including real FarmPlayer + 86 AnimalActor adapter lifecycle.
var _g3_benchmarks: Array[Dictionary] = []

func _tick_actor(actor: Node2D, point: Vector2, delta: float = 0.016667) -> void:
	actor.position = point
	_field.interactions.tick(delta, Rect2(-100, -100, 500, 500), _field.effect, true)

func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup([_sample(Vector2(128, 128), 6)])
	_field.set_interactions_enabled(true)
	_field.set_process(false)
	var actor: Node2D = Node2D.new()
	actor.position = Vector2(120, 128)
	_world.add_child(actor)
	_field.interactions.register_actor(actor, 28, 8)
	var baseline: Image = await _capture()
	_tick_actor(actor, actor.position)
	var bent: Image = await _capture()
	_check(bent.get_data() != baseline.get_data(), "Stationary actor bends actual grass pixels")
	baseline.save_png(_directory + "/grass-before.png")
	bent.save_png(_directory + "/grass-contact.png")
	_tick_actor(actor, actor.position, 0.4)
	_check(bent.get_data() == (await _capture()).get_data(), "Stationary pressure remains after recovery time")
	_field.effect.set_shader_parameter(&"debug_anchor_only", true)
	var anchor: Dictionary = _centroid(await _capture())
	_field.effect.set_shader_parameter(&"actor_count", 0)
	var original_anchor: Dictionary = _centroid(await _capture())
	_check(anchor.count > 0 and absf(anchor.x - original_anchor.x) <= 1.0 and absf(anchor.y - original_anchor.y) <= 1.0, "Opaque root stays pinned during actor bending")
	_field.effect.set_shader_parameter(&"debug_anchor_only", false)
	_tick_actor(actor, Vector2(128, 128))
	_check(_has_pixels(await _capture()), "Exact actor/root overlap is finite and visible")
	_field.interactions.entries[actor.get_instance_id()].radius = 10.0
	actor.position = Vector2(88, 128)
	_field.interactions.reset_motion(actor)
	_tick_actor(actor, Vector2(168, 128))
	_check(baseline.get_data() != (await _capture()).get_data(), "80px fast sweep affects grass between both outside endpoints")
	get_tree().paused = true
	var paused: Image = await _capture()
	await get_tree().create_timer(0.22, true, false, true).timeout
	_check(paused.get_data() == (await _capture()).get_data(), "Paused interaction clock preserves swept pressure while shader TIME keeps running")
	get_tree().paused = false
	_tick_actor(actor, actor.position, 0.25)
	_check(baseline.get_data() == (await _capture()).get_data(), "Swept trail recovers while stationary head stays outside")
	actor.position = Vector2(40, 128)
	_field.interactions.reset_motion(actor)
	_tick_actor(actor, Vector2(220, 128))
	_check(baseline.get_data() == (await _capture()).get_data(), "Teleport does not bend grass along the skipped route")
	_field.interactions.detach()
	var nodes: Array[Node2D] = []
	for i: int in range(86):
		nodes.append(_contact(Vector2(240, 240), 1))
	var near: Node2D = _contact(Vector2(120, 128), 28)
	_field.interactions.tick(0.02, Rect2(0, 0, 256, 256), _field.effect, true)
	_check(_field.interactions.uploaded == 87, "All 87 actors upload")
	_check(baseline.get_data() != (await _capture()).get_data(), "Slot 87 affects pixels on this GPU")
	near.position = Vector2(240, 240)
	for i: int in range(8):
		nodes.append(_contact(Vector2(240, 240), 1))
	near = _contact(Vector2(120, 128), 28)
	_field.interactions.tick(0.02, Rect2(0, 0, 256, 256), _field.effect, true)
	_check(_field.interactions.uploaded == 96, "All 96 supported actors upload")
	var last_slot: Image = await _capture()
	_field.effect.set_shader_parameter(&"actor_count", 95)
	_check(last_slot.get_data() != (await _capture()).get_data(), "Slot 96 affects pixels; shader does not stop at 16/32/87")
	var overflow: Node2D = _contact(Vector2(128, 128), 10)
	_field.interactions.tick(0.02, Rect2(0, 0, 256, 256), _field.effect, true)
	_check(_field.interactions.eligible == 97 and _field.interactions.uploaded == 0 and _field.interactions.last_error != "", "97 eligible actors report unsupported capacity, no silent truncation")
	_check(baseline.get_data() == (await _capture()).get_data(), "Overflow disables interaction uniformly and retains grass")
	overflow.free()
	_field.interactions.tick(0.0, Rect2(0, 0, 256, 256), _field.effect, true)
	# Exactly coincident actors saturate safely at 12px rather than sum unbounded.
	for entry: Dictionary in _field.interactions.entries.values():
		var node: Node2D = entry.ref.get_ref() as Node2D
		node.position = Vector2(128, 128)
		entry.radius = 28.0
		entry.angle = 0.0
		_field.interactions.reset_motion(node)
	_field.interactions.tick(0.02, Rect2(0, 0, 256, 256), _field.effect, true)
	var crowded: Image = await _capture()
	var one: PackedVector4Array = _field.interactions.parameters
	one[0] = Vector4(28, 12, _field.interactions.clock, 0)
	_field.effect.set_shader_parameter(&"actor_parameters", one)
	_field.effect.set_shader_parameter(&"actor_count", 1)
	_check(crowded.get_data() == (await _capture()).get_data(), "96 overlapping actors match bounded 12px reference")
	_clear_world()
	_setup([_sample(Vector2(128, 128), 6)])
	_world.position = Vector2(12, 8)
	_world.scale = Vector2(0.75, 1.5)
	_camera.force_update_scroll()
	_field.set_interactions_enabled(true)
	_field.set_process(false)
	var transformed_base: Image = await _capture()
	var transformed_actor: Node2D = _contact(Vector2(120, 128), 28)
	_field.interactions.tick(0.02, Rect2(-1000, -1000, 2000, 2000), _field.effect, true)
	_check(transformed_base.get_data() != (await _capture()).get_data(), "World-space actor bending survives transformed sort root")
	var feet: Vector4 = _field.interactions.segments[0]
	_check(Vector2(feet.z, feet.w) == transformed_actor.global_position, "Uniform feet use actual world position under parent transform")
	_clear_world()
	await _real_adapters()
	await _measure()
	await _g3_lab()
	var report: Dictionary = {"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string, "checks": _checks, "failures": _failures, "benchmarks": _g3_benchmarks,
		"capacity": 96, "mobile_tested": false, "gameplay_map_integrated": false}
	var file: FileAccess = FileAccess.open(_directory + "/g3-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GRASS_G3=" + JSON.stringify({"checks": _checks, "failures": _failures, "renderer": report.renderer}))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _contact(point: Vector2, radius: float) -> Node2D:
	var node: Node2D = Node2D.new()
	node.position = point
	_world.add_child(node)
	_field.interactions.register_actor(node, radius, 8)
	return node

func _centroid(image: Image) -> Dictionary:
	var bytes: PackedByteArray = image.get_data()
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for i: int in range(0, bytes.size(), 4):
		if bytes[i] > 240 and bytes[i + 1] < 8 and bytes[i + 2] > 240:
			var pixel: int = floori(float(i) / 4.0)
			sum += Vector2(pixel % image.get_width(), floori(float(pixel) / float(image.get_width())))
			count += 1
	return {"x": sum.x / maxi(1, count), "y": sum.y / maxi(1, count), "count": count}

func _real_adapters() -> void:
	var farm: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	farm.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(farm) # Child of QA scene, WorldPersistence does NOT bind SaveManager.
	await get_tree().process_frame
	var feed: GrassInteractionFeed = GrassInteractionFeed.new()
	feed.attach(farm)
	var pen: AnimalPen = AnimalPen.new()
	pen.y_sort_enabled = true
	farm.add_child(pen)
	var animals: Array[AnimalActor] = []
	var counts: Dictionary = {"chicken": 30, "duck": 10, "goose": 10, "cow": 12, "sheep": 8, "pig": 8, "horse": 8}
	for species: String in counts:
		for i: int in range(int(counts[species])):
			var animal: AnimalActor = load("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
			animal.definition = load("res://animals/definitions/" + species + ".tres") as AnimalDefinition
			animal.position = Vector2(100 + i * 8, 100)
			pen.add_child(animal)
			animals.append(animal)
	await get_tree().process_frame
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://shaders/grass_field.gdshader")
	feed.tick(0.02, Rect2(-100000, -100000, 200000, 200000), material, true)
	_check(feed.entries.has(farm.player.get_instance_id()), "Real FarmPlayer discovered from existing group")
	_check(feed.uploaded == 87, "Real player + 86 animals of seven species discovered without new actor components")
	animals[0].retire_for_sale()
	animals[1]._die()
	feed.tick(0.02, Rect2(-100000, -100000, 200000, 200000), material, true)
	_check(feed.uploaded == 85, "Sale and death remove real actors from uploaded pressure")
	farm.free()
	_check(feed.entries.is_empty(), "World exit clears registry via node_removed")
	feed.detach()

func _measure() -> void:
	get_tree().root.size = Vector2i(640, 480)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for hz: int in [30, 60]:
		for count: int in [0, 1, 16, 87, 96]:
			_world = Node2D.new()
			_world.y_sort_enabled = true
			add_child(_world)
			_camera = Camera2D.new()
			_camera.position = Vector2(320, 240)
			_world.add_child(_camera)
			_field = GrassChunkField.new()
			_field.samples = _dataset(0)
			_field.interaction_enabled = true
			_field.interaction_hz = hz
			_world.add_child(_field)
			_field.set_process(false)
			var actors: Array[Node2D] = []
			for i: int in range(count):
				actors.append(_contact(Vector2(100 + i % 16 * 28, 100 + floori(float(i) / 16.0) * 40), 14))
			var raw_gpu: Array[float] = []
			var raw_cpu: Array[float] = []
			var raw_feed: Array[float] = []
			var upload_before: int = 0
			for frame: int in range(90):
				for i: int in range(actors.size()):
					actors[i].position.x += sin(float(frame + i) * 0.1) * 0.7
				var began: int = Time.get_ticks_usec()
				_field._process(1.0 / 60.0)
				var feed_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
				await RenderingServer.frame_post_draw
				if frame == 29:
					upload_before = _field.interactions.uploads
				if frame >= 30:
					raw_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
					raw_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
					raw_feed.append(feed_ms)
			_check(_field.interactions.uploaded == count, "Benchmark retains all %d actors at %dHz" % [count, hz])
			_check(_field.interactions.uploads - upload_before == hz, "Measured uniform cadence %dHz with 60 frame samples" % hz)
			_g3_benchmarks.append({"actors": count, "hz": hz, "grass_instances_dataset": 4096, "viewport": [640, 480], "fps_cap": 60,
				"cache": _field.renderer.stats(), "feed": _field.interactions.stats(), "gpu_ms": _summary(raw_gpu), "render_cpu_ms": _summary(raw_cpu),
				"manager_cpu_ms": _summary(raw_feed), "raw_samples": {"gpu_ms": raw_gpu, "render_cpu_ms": raw_cpu, "manager_cpu_ms": raw_feed}})
			_clear_world()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)

func _g3_lab() -> void:
	var lab: Node2D = load("res://tests/support/grass_gpu_interactions_poc.tscn").instantiate() as Node2D
	add_child(lab)
	await get_tree().create_timer(0.3).timeout
	_check(lab.field.interactions.entries.size() == 87 and lab.field.interactions.uploaded == 87, "Interactive lab registers full 87 actors")
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_U
	lab._unhandled_input(key)
	_check(lab.field.interaction_hz == 30, "Lab changes upload rate")
	key.keycode = KEY_I
	lab._unhandled_input(key)
	_check(not lab.field.interaction_enabled and lab.field.interactions.entries.is_empty(), "Lab disables and detaches feed")
	lab._unhandled_input(key)
	await get_tree().create_timer(0.1).timeout
	_check(lab.field.interactions.uploaded == 87, "Lab reenable restores all 87 actors")
	key.keycode = KEY_R
	lab._unhandled_input(key)
	await get_tree().create_timer(0.05).timeout
	_check(lab.field.interactions.uploaded == 87, "Chunk rebuild preserves actor feed")
	key.keycode = KEY_M
	lab._unhandled_input(key)
	var still: Vector2 = lab.animal.position
	var still_member: Vector2 = lab.herd[0].position
	await get_tree().create_timer(0.1).timeout
	_check(lab.animal.position == still and lab.herd[0].position == still_member, "Freeze control keeps herd still and pressure active")
	lab._unhandled_input(key)
	key.keycode = KEY_F
	lab._unhandled_input(key)
	await get_tree().create_timer(0.2).timeout
	_check(lab.field.interactions.last_error == "", "Lab teleport/camera change does not overflow registry")
	lab.player.position -= Vector2(320, 0)
	lab.field.interactions.reset_motion(lab.player)
	await get_tree().create_timer(0.2).timeout
	(await _capture()).save_png(_directory + "/g3-lab.png")
	lab.free()
