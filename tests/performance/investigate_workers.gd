extends Node
## Isolated CPU diagnosis. Does not assign current_scene or bind a save profile.
## Run this .tscn in an imported staging project. Optional args: OUTPUT_JSON WORKER_COUNT.
## Numbers are component timings, not rendered FPS. World processing is manual.
class TimedPolicy extends CropWorkerPolicy:
	var skip_busy: bool = false
	var busy_calls: int = 0
	var idle_calls: int = 0
	var elapsed_usec: int = 0
	func planting_task(row: Dictionary) -> Dictionary:
		var occupied: bool = not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"]
		if occupied:
			busy_calls += 1
		else:
			idle_calls += 1
		if skip_busy and occupied:
			return {}
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.planting_task(row)
		elapsed_usec += Time.get_ticks_usec() - started
		return result

var root: Window
var world: FarmWorld
var now: float = 1793500000.0
var results: Array[Dictionary] = []

func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()

func _run() -> void:
	root.get_node("TimeManager").set_process(false)
	root.get_node("TimeManager").clock_source = func() -> float: return now
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var counts: Array[int] = [0, 1, 5, 15]
	if args.size() > 1:
		counts.assign([0, 15] if args[1] == "all" else [int(args[1])])
	for count: int in counts:
		if args.has("live"):
			await _live_scenario(count, true)
		else:
			await _scenario(count, true)
	if args.size() <= 1:
		await _scenario(15, false)
	elif args.has("live"):
		await _live_scenario(15, false)
	elif args[1] == "all":
		await _scenario(15, false)
	var report: Dictionary = {"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "manual_frames_per_case": 180, "live_seconds_per_case": 18, "max_fps": Engine.max_fps, "save_bound": root.get_node("SaveManager").adapter != null, "scenarios": results}
	var output: String = args[0] if not args.is_empty() else "C:/projects/fantasy-farm/docs/worker_investigation_2026-11-01.json"
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("WORKER_INVESTIGATION ", JSON.stringify(report))
	get_tree().quit()

func _live_scenario(count: int, planting: bool) -> void:
	seed(12345)
	var clock: FarmClock = root.get_node("TimeManager") as FarmClock
	var baseline: float = now
	var clock_start: int = Time.get_ticks_usec()
	clock.clock_source = func() -> float: return baseline + float(Time.get_ticks_usec() - clock_start) / 1000000.0
	clock.set_process(true)
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	root.add_child(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_blocks(16, 8)
	world.player.wallet.set_balance(10000000)
	world.storages.inventory("farm_supply_storage").add(load("res://items/seeds/carrot_seed.tres") as ItemDefinition, 1000)
	for index: int in range(count):
		assert(world.workers.hire("crop").is_empty())
	world.workers.configure_crop(planting, false, false)
	var metrics: Dictionary = {}
	for key: String in ["frame_ms", "process_ms", "physics_ms", "gpu_ms"]:
		var samples: Array[float] = []
		metrics[key] = samples
	var origins: Dictionary = {}
	for actor: WorkerActor in world.workers.actors.values():
		origins[actor.persistent_id] = actor.global_position
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	while Time.get_ticks_usec() - started < 18000000:
		await get_tree().process_frame
		var current: int = Time.get_ticks_usec()
		metrics.frame_ms.append(float(current - previous) / 1000.0)
		previous = current
		metrics.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		metrics.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		metrics.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	var summary: Dictionary = {}
	for key: String in metrics:
		summary[key] = _stats(metrics[key])
	var displaced: int = 0
	var tasks: Dictionary = {}
	for actor: WorkerActor in world.workers.actors.values():
		if actor.global_position.distance_to(origins[actor.persistent_id]) > 16.0:
			displaced += 1
		var row: Dictionary = world.workers.record_for(String(actor.persistent_id))
		var kind: String = String(row.task.get("kind", "none"))
		tasks[kind] = int(tasks.get(kind, 0)) + 1
	var navigation: WorkerNavigationSystem = world.workers.get("navigation") as WorkerNavigationSystem
	var result: Dictionary = {"mode": "live", "workers": count, "planting": planting, "seconds": float(Time.get_ticks_usec() - started) / 1000000.0, "fps": metrics.frame_ms.size() * 1000000.0 / float(Time.get_ticks_usec() - started), "stats": summary, "displaced_workers": displaced, "planted_crops": world.workers.crop_automation.sequence, "tasks_at_end": tasks, "completed_paths": navigation.completed_paths if navigation != null else -1, "failed_paths": navigation.failed_paths if navigation != null else -1, "pending_paths": navigation.jobs.size() if navigation != null else -1, "shared_caches": navigation.caches.size() if navigation != null else 0, "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method()}
	result.frames_over_33ms = metrics.frame_ms.filter(func(value: float) -> bool: return value > 33.333).size()
	result.frames_over_50ms = metrics.frame_ms.filter(func(value: float) -> bool: return value > 50.0).size()
	result.vsync = DisplayServer.window_get_vsync_mode()
	if DisplayServer.get_name() != "headless" and count == 15 and planting:
		var output: String = OS.get_cmdline_user_args()[0]
		root.get_texture().get_image().save_png(output.get_basename() + "-15-workers.png")
	results.append(result)
	print("LIVE_CASE ", JSON.stringify(result))
	now = clock.now()
	clock.set_process(false)
	clock.clock_source = func() -> float: return now
	world.free()
	await get_tree().process_frame

func _scenario(count: int, planting: bool) -> void:
	seed(12345)
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var policy: TimedPolicy = TimedPolicy.new(world)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	policy.skip_busy = args.size() > 2 and args[2] == "skip_busy_planting"
	world.workers.crop_policy = policy
	world.farming.time_manager.clock_source = func() -> float: return now
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(10000000)
	world.land.state.restore_blocks(16, 8)
	world.storages.inventory("farm_supply_storage").add(load("res://items/seeds/carrot_seed.tres") as ItemDefinition, 1000)
	for index: int in range(count):
		var error: String = world.workers.hire("crop")
		assert(error.is_empty(), error)
		# Fixed IDs and separated spawn points make runs repeatable.
		var row: Dictionary = world.workers.records[index]
		var actor: WorkerActor = world.workers.actors[row.id] as WorkerActor
		world.workers.actors.erase(row.id)
		row.id = "probe_worker_%02d" % index
		actor.persistent_id = StringName(row.id)
		world.workers.actors[row.id] = actor
	world.workers.configure_crop(planting, false, false)
	# CharacterBody2D must stay registered in physics even with manual stepping.
	# Disabling the entire world removes bodies from their physics space.
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.workers.set_process(false)
	world.player.state.set_physics_process(false)
	var navigation: WorkerNavigationSystem = world.workers.get("navigation") as WorkerNavigationSystem
	if navigation != null:
		navigation.set_physics_process(false)
	for actor: WorkerActor in world.workers.actors.values():
		actor.behaviour.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().process_frame
	var service_ms: Array[float] = []
	var movement_ms: Array[float] = []
	var query_steps: Array[float] = []
	var last_queries: int = 0
	policy.busy_calls = 0
	policy.idle_calls = 0
	policy.elapsed_usec = 0
	for frame: int in range(180):
		now += 1.0 / 60.0
		var started: int = Time.get_ticks_usec()
		if frame % 15 == 0:
			world.workers.advance(now, false)
			service_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
		started = Time.get_ticks_usec()
		if navigation != null:
			navigation.pump()
		for actor: WorkerActor in world.workers.actors.values():
			actor.behaviour._step(1.0 / 60.0)
		movement_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
		var queries: int = 0
		for actor: WorkerActor in world.workers.actors.values():
			if actor.behaviour._navigation != null:
				queries += actor.behaviour._navigation.total_physics_queries
		query_steps.append(float(queries - last_queries))
		last_queries = queries
		await get_tree().physics_frame
		await get_tree().process_frame
	var tasks: Dictionary = {}
	var grids: int = 0
	var sampled: int = 0
	for actor: WorkerActor in world.workers.actors.values():
		var row: Dictionary = world.workers.record_for(String(actor.persistent_id))
		var kind: String = String(row.task.get("kind", "none"))
		tasks[kind] = int(tasks.get(kind, 0)) + 1
		var nav: PlayerNavigationComponent = actor.behaviour._navigation
		if nav != null and nav._grid != null:
			grids += 1
			sampled += nav._sampled.size()
	var result: Dictionary = {"workers": count, "planting": planting, "scheduler_tick_ms": _stats(service_ms), "movement_step_ms": _stats(movement_ms), "navigation_queries_per_step": _stats(query_steps), "navigation_queries_total": last_queries, "private_grids": grids, "sampled_cells": sampled, "tasks_at_end": tasks}
	result.policy_measurement = {"skip_busy_planting": policy.skip_busy, "busy_calls": policy.busy_calls, "idle_calls": policy.idle_calls, "total_ms": float(policy.elapsed_usec) / 1000.0}
	result.scheduler_samples_ms = service_ms
	if navigation != null:
		result.navigation = {"shared_caches": navigation.caches.size(), "queries": navigation.total_queries, "completed_paths": navigation.completed_paths, "pending_paths": navigation.jobs.size()}
	if count == 15 and planting:
		var row: Dictionary = world.workers.records[-1]
		var timings: Dictionary = {"policy_cells": world.workers.crop_policy.cells.size(), "task": row.task.get("kind", "none")}
		var started: int = Time.get_ticks_usec()
		world.workers.crop_policy.planting_task(row)
		timings.planting_task_ms = float(Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		world.workers.bridge.candidates(row, world.workers.feed_inventory(row.id))
		timings.candidates_ms = float(Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		world.workers.bridge.next_wake(row, world.workers.feed_inventory(row.id), now)
		timings.next_wake_ms = float(Time.get_ticks_usec() - started) / 1000.0
		result.component_probe = timings
	results.append(result)
	print("CASE ", JSON.stringify(result))
	world.free()
	await get_tree().process_frame

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"mean": total / values.size(), "p50": values[clampi(ceili(values.size() * 0.5) - 1, 0, values.size() - 1)], "p95": values[clampi(ceili(values.size() * 0.95) - 1, 0, values.size() - 1)], "p99": values[clampi(ceili(values.size() * 0.99) - 1, 0, values.size() - 1)], "max": values[-1]}


