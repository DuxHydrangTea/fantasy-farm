extends SceneTree
## Worker performance profiling: measures FPS with varying worker counts (1, 5, 10, 15).
## Usage: godot --script tests/performance/profile_workers.gd -- output.json

var config: Dictionary = {}
var report: Dictionary = {}
var world: FarmWorld
var viewport_rid: RID

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "worker_profile.json"
	config = {"output": output, "warmup_seconds": 2.0, "measure_seconds": 15.0, "worker_counts": [0, 1, 5, 10, 15]}
	_run.call_deferred()

func _run() -> void:
	seed(20261031)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	
	# Load world with full farm + orchard
	var save_manager: Node = root.get_node("SaveManager")
	var packed: PackedScene = load("res://world/main_world.tscn") as PackedScene
	world = packed.instantiate() as FarmWorld
	root.add_child(world)
	current_scene = world
	
	await create_timer(5.0).timeout
	while save_manager.busy:
		await process_frame
	
	if not save_manager.writes_enabled:
		push_error("Profile did not load")
		quit(2)
		return
	
	# Expand land and prepare world
	world.land.state.restore_columns(16, 8)
	world.tree_plot_upgrades.state.restore({"fruit": 10, "timber": 1})
	world.player.wallet.set_balance(10000000)
	world.tool_upgrades.profile_ready = true
	
	# Plant fruit trees for workers to harvest
	var now: float = world.farming.time_manager.now()
	for index: int in range(10):
		var cell: Vector2i = Vector2i(12 + index * 3, 61)
		var tree: FruitTree = world.trees.create_tree(cell, world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1.0
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds * 0.9
		tree.refresh(now)
	
	# Plant crops for workers
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	world.storages.inventory("farm_supply_storage").add(seed, 1000)
	for x: int in range(48, 64):
		for y: int in range(20, 36):
			var cell: Vector2i = Vector2i(x, y)
			if world.farming.can_till(cell, null):
				world.farming.apply_area(&"tool", [cell], null, -1, null, null)
	
	# Add feed for ranch work
	world.storages.inventory("farm_supply_storage").add(load("res://items/feeds/livestock_feed.tres"), 500)
	world.storages.inventory("farm_supply_storage").add(load("res://items/feeds/poultry_feed.tres"), 500)
	
	await wait_physics_frames(5)
	
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	
	report = {
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"window_size": str(DisplayServer.window_get_size()),
		"max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"test_time": Time.get_datetime_string_from_system(),
		"scenarios": [],
		"config": config,
	}
	
	# Test with different worker counts
	for count: int in config["worker_counts"]:
		print("[WORKER_PROFILE] Testing with %d workers..." % count)
		await _test_scenario(count)
		_write_report()
	
	report["completed"] = true
	_write_report()
	print("[WORKER_PROFILE] Complete. Report: ", config["output"])
	quit(0)

func _test_scenario(worker_count: int) -> void:
	# Dismiss all workers first
	while not world.workers.record("crop").is_empty():
		world.workers.dismiss("crop")
	
	# Hire workers
	for i: int in range(worker_count):
		var error: String = world.workers.hire("crop")
		if not error.is_empty():
			push_warning("Failed to hire worker %d/%d: %s" % [i + 1, worker_count, error])
			break
	
	# Enable crop automation
	if worker_count > 0:
		world.workers.configure_crop(true, true, false)
	
	# Warmup
	await create_timer(config["warmup_seconds"]).timeout
	
	# Measure
	var metrics: Dictionary = {}
	for metric: String in ["frame_ms", "process_ms", "physics_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "nodes", "physics_2d_active_objects"]:
		metrics[metric] = []
	
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var duration: float = config["measure_seconds"]
	var worker_samples: Array[Dictionary] = []
	
	while float(Time.get_ticks_usec() - started) / 1000000.0 < duration:
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		metrics["frame_ms"].append(float(now_usec - previous) / 1000.0)
		previous = now_usec
		
		metrics["process_ms"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		metrics["physics_ms"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		metrics["render_cpu_ms"].append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		metrics["render_gpu_ms"].append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		metrics["draw_calls"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		metrics["nodes"].append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		metrics["physics_2d_active_objects"].append(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
		
		# Sample worker states every 30 frames
		if metrics["frame_ms"].size() % 30 == 0 and worker_count > 0:
			var sample: Dictionary = {"frame": metrics["frame_ms"].size(), "workers": []}
			for row: Dictionary in world.workers.records:
				if row.employed:
					sample.workers.append({
						"id": String(row.id).substr(0, 12),
						"active": row.active,
						"task_kind": String(row.task.get("kind", "none")),
						"has_navigation": world.workers.actor_for(row.id).behaviour._navigation != null
					})
			worker_samples.append(sample)
	
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
	var summary: Dictionary = {}
	for metric: String in metrics:
		summary[metric] = _stats(metrics[metric])
	
	var result: Dictionary = {
		"worker_count": worker_count,
		"seconds": elapsed,
		"fps": float(metrics["frame_ms"].size()) / elapsed,
		"frames_over_16ms": metrics["frame_ms"].filter(func(v: float) -> bool: return v > 16.666).size(),
		"frames_over_33ms": metrics["frame_ms"].filter(func(v: float) -> bool: return v > 33.333).size(),
		"frames_over_50ms": metrics["frame_ms"].filter(func(v: float) -> bool: return v > 50.0).size(),
		"worker_samples": worker_samples,
		"stats": summary,
	}
	
	report["scenarios"].append(result)
	print("[WORKER_PROFILE] Workers=%d FPS=%.1f frames_over_33ms=%d" % [worker_count, result.fps, result.frames_over_33ms])

func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"samples": 0, "avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "min": 0.0, "max": 0.0}
	values.sort()
	var count: int = values.size()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"samples": count,
		"avg": total / count,
		"p50": values[clampi(ceili(count * 0.5) - 1, 0, count - 1)],
		"p95": values[clampi(ceili(count * 0.95) - 1, 0, count - 1)],
		"p99": values[clampi(ceili(count * 0.99) - 1, 0, count - 1)],
		"min": values[0],
		"max": values[count - 1]
	}

func _write_report() -> void:
	var file: FileAccess = FileAccess.open(config["output"], FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
