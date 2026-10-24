extends Node2D
## Real MainWorld as child: persistence never binds this QA world to user saves.
var world: FarmWorld
var _directory: String
var _checks: int = 0
var _failures: Array[String] = []
var _metrics: Array[Dictionary] = []

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_directory = args[0] if not args.is_empty() else "user://grass-g4"
	DirAccess.make_dir_recursive_absolute(_directory)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error(label)

func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Image = get_viewport().get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result

func _cells(layer: TileMapLayer) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		result[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)]
	return result

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	await get_tree().process_frame
	world.player.global_position = Vector2(1408, 576)
	world.player.camera.zoom = Vector2.ONE
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	world.weather.set_debug_hour(12)
	await get_tree().create_timer(0.2).timeout
	var field: FarmGrassField = world.grass
	var layer: TileMapLayer = world.get_node("TinyDecor")
	_check(field.active and field.transfer.records.size() == 10 and field.transfer.retained_overlaps == 3, "Real world enables 10 safe grass cells; 3 mixed-row overlaps stay authored")
	_check(field.get_child_count() == 0, "Grass integration adds one feature node")
	_check(layer.visible, "Mixed TinyDecor layer remains visible")
	field.set_conversion(false)
	var original: Dictionary = _cells(layer)
	Engine.time_scale = 0.0
	world.process_mode = Node.PROCESS_MODE_DISABLED
	# Compare source/GPU at both noon and midnight, with wind/actors off for fidelity.
	for hour: int in [12, 0]:
		world.weather.set_debug_hour(hour)
		field.set_conversion(false)
		var source: Image = await _capture()
		_check(field.set_conversion(true), "GPU transaction succeeds hour " + str(hour))
		field.set_process(false)
		field.effect.set_shader_parameter(&"wind_strength", 0.0)
		field.effect.set_shader_parameter(&"actor_count", 0)
		var gpu: Image = await _capture()
		var delta: float = float(gpu.compute_image_metrics(source, false).get("max", 255.0))
		_check(delta <= 1.0, "Authored pixels and lighting match at hour %d (delta %f)" % [hour, delta])
		source.save_png(_directory + "/source-%d.png" % hour)
		gpu.save_png(_directory + "/gpu-%d.png" % hour)
		field.set_conversion(false)
		_check(_cells(layer) == original, "Toggle restores every authored cell at hour " + str(hour))
	world.weather.set_debug_hour(12)
	for zoom_value: float in [0.8, 1.25]:
		world.player.camera.zoom = Vector2.ONE * zoom_value
		world.player.camera.force_update_scroll()
		field.set_conversion(false)
		var source_zoom: Image = await _capture()
		field.set_conversion(true)
		field.set_process(false)
		field.effect.set_shader_parameter(&"wind_strength", 0.0)
		field.effect.set_shader_parameter(&"actor_count", 0)
		var gpu_zoom: Image = await _capture()
		source_zoom.save_png(_directory + "/source-zoom-%s.png" % str(zoom_value))
		gpu_zoom.save_png(_directory + "/gpu-zoom-%s.png" % str(zoom_value))
		_check(float(gpu_zoom.compute_image_metrics(source_zoom, false).get("max", 255.0)) <= 1.0, "Authored TileMap parity at fractional camera zoom " + str(zoom_value))
	world.player.camera.zoom = Vector2.ONE
	world.player.camera.force_update_scroll()
	# Guard both source tuple and weather signal/transition values.
	field.set_conversion(true)
	for mode: int in [WeatherManager.Weather.SUNNY, WeatherManager.Weather.CLOUDY, WeatherManager.Weather.RAIN, WeatherManager.Weather.WINDY]:
		world.weather.effects._activate(mode)
		world.weather.effects.strength = 1.0
		field._sync_environment()
		_check(is_equal_approx(field.wind_strength, [0.65, 1.0, 1.2, 2.8][[0, 2, 1, 3].find(mode)]), "Grass follows weather mode " + str(mode))
	# Runtime failure must bring back ALL originals, then allow retry.
	field.set_conversion(false)
	var fallback_reference: Image = await _capture()
	field.set_conversion(true)
	field.max_resident_batches = 1
	field.rebuild()
	field._process(0.0)
	_check(not field.active and _cells(layer) == original, "Budget failure restores source without holes")
	_check(field.renderer.resident.is_empty(), "Fallback releases GPU cache")
	_check(fallback_reference.get_data() == (await _capture()).get_data(), "Budget fallback renders the complete original image")
	field.max_resident_batches = 2048
	field.rebuild()
	_check(field.set_conversion(true), "Retry recovers after restoring budget")
	var atlas: Texture2D = field.catalog.texture
	field.catalog.texture = null
	_check(not field.set_conversion(true) and _cells(layer) == original, "Unavailable atlas restores every original cell")
	_check(fallback_reference.get_data() == (await _capture()).get_data(), "Atlas fallback renders the complete original image")
	field.catalog.texture = atlas
	_check(field.set_conversion(true), "Atlas recovery enables GPU again")
	var shader: Shader = field.field_shader
	field.field_shader = null
	_check(not field.set_conversion(true) and _cells(layer) == original, "Unavailable shader restores every original cell")
	_check(fallback_reference.get_data() == (await _capture()).get_data(), "Shader fallback renders the complete original image")
	field.field_shader = shader
	_check(field.set_conversion(true), "Shader recovery enables GPU again")
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F10
	field._unhandled_key_input(event)
	_check(not field.active and _cells(layer) == original, "F10 restores source")
	field._unhandled_key_input(event)
	_check(field.active, "F10 restores GPU rendering")
	await _save_and_reload()
	await _actual_herd()
	world.free()
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	_check(world.grass.active and world.grass.transfer.records.size() == 10, "Scene reload creates a clean GPU transaction")
	world.grass.set_conversion(false)
	_check((world.get_node("TinyDecor") as TileMapLayer).get_used_cells().size() == 1130, "Scene reload retains full authored source without accumulation")
	world.free()
	Engine.time_scale = 1.0
	var preview: Node2D = load("res://tests/support/grass_gpu_farm_preview.tscn").instantiate() as Node2D
	add_child(preview)
	await get_tree().create_timer(0.3).timeout
	_check(preview.world.grass.active, "F6 isolated preview runs integrated GPU grass")
	_check(preview.world.grass.interactions.entries.size() == 37, "Preview has actual player and 36 QA livestock")
	(await _capture()).save_png(_directory + "/preview-barn.png")
	preview.free()
	var report: Dictionary = {"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string,
		"checks": _checks, "failures": _failures, "trial_region": [1008, 592, 384, 272], "converted_cells": 10, "retained_overlaps": 3,
		"metrics": _metrics, "personal_save_used": false, "mobile_browser_tested": false}
	var file: FileAccess = FileAccess.open(_directory + "/g4-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GRASS_G4=" + JSON.stringify({"checks": _checks, "failures": _failures, "renderer": report.renderer}))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _save_and_reload() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = TimeManager.now()
	var before: Dictionary = adapter.capture("grass_g4_isolated", 1, now)
	world.grass.set_conversion(false)
	var after: Dictionary = adapter.capture("grass_g4_isolated", 1, now)
	_check(before == after, "GPU/source toggles do not change economic save DTO")
	_check(not JSON.stringify(before).contains("grass" + "_instances"), "Grass data does not enter save schema")
	# Exercise the same in-memory restore pipeline as save/load; no disk profile.
	before.player.position[0] += 32.0
	var restored: Dictionary = adapter.restore(before, now)
	_check(restored.ok, "Existing save DTO restores successfully")
	var entry: Dictionary = world.grass.interactions.entries[world.player.get_instance_id()]
	_check(entry.tail == world.player.global_position, "Short save/load teleport resets grass motion history")
	world.grass.set_conversion(true)
	_check(world.grass.active and world.farming.land.unlocked_columns == 4, "Save/load keeps grass active and progression intact")
	await get_tree().process_frame

func _actual_herd() -> void:
	Engine.time_scale = 1.0
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.weather.effects._activate(WeatherManager.Weather.SUNNY)
	world.weather.effects.strength = 1.0
	world.weather.set_debug_hour(12)
	var counts: Dictionary = {"chicken": 30, "duck": 10, "goose": 10, "cow": 12, "sheep": 8, "pig": 8, "horse": 8}
	var first: AnimalActor
	for species: String in counts:
		var pen: AnimalPen = world.get_node("CoopPen" if species == "chicken" else "PondPen" if species in ["duck", "goose"] else "BarnPen")
		for i: int in range(int(counts[species])):
			var actor: AnimalActor = load("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
			actor.definition = load("res://animals/definitions/" + species + ".tres")
			actor.initial_age_seconds = actor.definition.maturity_seconds + 10.0
			actor.position = Vector2(32 + i % 8 * 40, 40 + floori(float(i) / 8.0) * 40)
			pen.add_child(actor)
			if species == "cow" and i == 0:
				first = actor
	first.global_position = Vector2(1276, 832)
	await get_tree().create_timer(0.4).timeout
	_check(world.grass.interactions.entries.size() == 87, "Real player and full 86-animal herd registered in gameplay world")
	_check(world.grass.active and world.grass.interactions.last_error == "", "Gameplay AI runs without forcing grass fallback")
	world.player.selection.set_inventory_open(true)
	await get_tree().create_timer(0.1).timeout
	_check(world.player.selection.inventory_open and world.grass.active, "Inventory menu does not disturb grass integration")
	world.player.selection.set_inventory_open(false)
	world.player.global_position = Vector2(1298, 826)
	world.grass.interactions.reset_motion(world.player)
	var player_before: Vector2 = world.player.global_position
	Input.action_press(&"move_right")
	await get_tree().create_timer(0.12).timeout
	Input.action_release(&"move_right")
	_check(world.player.global_position.x > player_before.x, "Actual player input moves through barn grass without new collision")
	world.player.global_position = Vector2(1408, 576)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.grass.interactions.reset_motion(world.player)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	var uploads_before: int = world.grass.interactions.uploads
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(world.grass.active and world.grass.interactions.uploads == uploads_before, "Pause keeps source transaction and freezes actor feed")
	get_tree().paused = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	# Measure fixed camera with actual AI active (one short diagnostic sample).
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	for i: int in range(60):
		await RenderingServer.frame_post_draw
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	_metrics.append({"case": "real_world_86_animals_AI", "feed": world.grass.interactions.stats(), "cache": world.grass.renderer.stats(),
		"render_cpu_ms": cpu, "gpu_ms": gpu, "sample_frames": 60, "fps_cap": 60})
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	(await _capture()).save_png(_directory + "/farm-herd-gpu.png")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.0
	world.grass.set_conversion(false)
	(await _capture()).save_png(_directory + "/farm-herd-source.png")
	world.grass.set_conversion(true)
	world.grass.set_process(false)
	var count: int = int(world.grass.effect.get_shader_parameter(&"actor_count"))
	_check(count > 0 and count <= 96, "Visible real actors upload into shared farm shader")
	# Clear wind and compare pressure alone, with a real cow at known grass contact.
	first.global_position = Vector2(1276, 832)
	world.grass.interactions.reset_motion(first)
	world.grass.interactions.tick(0.02, Rect2(0, 0, 3000, 3000), world.grass.effect, true)
	world.grass.effect.set_shader_parameter(&"wind_strength", 0.0)
	var contact: Image = await _capture()
	world.grass.effect.set_shader_parameter(&"actor_count", 0)
	_check(contact.get_data() != (await _capture()).get_data(), "Real cow changes grass pixels in actual barn region")
	await _fixed_motion(first)
	# Capacity fallback is a transaction over the whole selected region, not a partial herd.
	var field: FarmGrassField = world.grass
	var layer: TileMapLayer = world.get_node("TinyDecor")
	field.set_conversion(false)
	var original: Dictionary = _cells(layer)
	field.set_conversion(true)
	var extras: Array[Node2D] = []
	for i: int in range(10):
		var actor: Node2D = Node2D.new()
		actor.position = Vector2(1250, 656)
		world.add_child(actor)
		field.interactions.register_actor(actor)
		extras.append(actor)
	field._process(0.0)
	_check(not field.active and field.fallback_reason.contains("97") and _cells(layer) == original, "97 eligible actors trigger whole-region source fallback")
	for actor: Node2D in extras:
		actor.free()
	_check(field.set_conversion(true), "Retry recovers after removing unsupported extra actors")
	world.remove_child(field)
	_check(_cells(layer) == original and field.renderer.resident.is_empty(), "Field exit restores cells and frees owned RIDs")
	world.add_child(field)
	_check(field.active and field.interactions.uploaded == 87, "Field reenter rebuilds visuals and real-actor registry")

func _fixed_motion(cow: AnimalActor) -> void:
	# Same poses/camera in both cases. AI, animation and TIME are frozen here.
	var camera_offset: Vector2 = world.player.camera.position
	var player_point: Vector2 = world.player.global_position
	var cow_point: Vector2 = cow.global_position
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for converted: bool in [false, true]:
		world.grass.set_conversion(converted)
		world.grass.set_process(false)
		if converted:
			world.grass._last_wind = -1.0
			world.grass._sync_environment()
		var cpu: Array[float] = []
		var gpu: Array[float] = []
		var manager: Array[float] = []
		for frame: int in range(90):
			var phase: float = float(frame) / 60.0
			world.player.global_position = Vector2(1268 + sin(phase * 2.0) * 36, 826)
			cow.global_position = Vector2(1276 + cos(phase * 1.7) * 12, 832)
			world.player.camera.global_position = Vector2(1408, 576)
			world.player.camera.force_update_scroll()
			var began: int = Time.get_ticks_usec()
			if converted:
				world.grass._process(1.0 / 60.0)
			var elapsed: float = float(Time.get_ticks_usec() - began) / 1000.0
			await RenderingServer.frame_post_draw
			if frame >= 30:
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
				manager.append(elapsed)
		_check(world.grass.active == converted, "Fixed-pose benchmark keeps requested source/GPU mode")
		_metrics.append({"case": "fixed_motion_gpu" if converted else "fixed_motion_source", "sample_frames": 60, "warmup_frames": 30,
			"fps_cap": 60, "viewport": [1280, 720], "ai_frozen": true, "render_cpu_ms": cpu, "gpu_ms": gpu, "grass_manager_cpu_ms": manager,
			"draw_calls_last": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"cache": world.grass.renderer.stats(), "feed": world.grass.interactions.stats()})
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	world.player.global_position = player_point
	cow.global_position = cow_point
	world.player.camera.position = camera_offset
	world.player.camera.force_update_scroll()
	world.grass.interactions.reset_all_motion()
