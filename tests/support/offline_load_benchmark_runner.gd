extends Node
## Read-only workload probe. The Python launcher supplies isolated saves/userdata.
class MeasuredBridge extends WorkerWorldBridge:
	var metrics: Dictionary = {}
	func record(key: String, started: int) -> void:
		var row: Dictionary = metrics.get(key, {"calls": 0, "usec": 0})
		row.calls += 1
		row.usec += Time.get_ticks_usec() - started
		metrics[key] = row
	func sync(timestamp: float, offline: bool = true) -> void:
		var stamp: int = Time.get_ticks_usec()
		world.weather.advance(timestamp, not offline)
		record("sync_weather", stamp)
		var farm_stamp: int = Time.get_ticks_usec()
		world.farming._refresh_crops(timestamp)
		record("sync_farming", farm_stamp)
		var pen_stamp: int = Time.get_ticks_usec()
		if offline:
			for pen: AnimalPen in pens():
				pen.advance_offline(timestamp, true)
		record("sync_pens", pen_stamp)
		record("sync", stamp)
	func candidates(row: Dictionary, bag: InventoryComponent) -> Array[Dictionary]:
		var stamp: int = Time.get_ticks_usec()
		var result: Array[Dictionary] = super.candidates(row, bag)
		record("candidates_" + String(row.role), stamp)
		return result
	func next_wake(row: Dictionary, bag: InventoryComponent, now: float) -> float:
		var stamp: int = Time.get_ticks_usec()
		var result: float = super.next_wake(row, bag, now)
		record("next_wake_" + String(row.role), stamp)
		return result
	func commit(row: Dictionary, bag: InventoryComponent, task: Dictionary) -> bool:
		var stamp: int = Time.get_ticks_usec()
		var result: bool = super.commit(row, bag, task)
		record("commit_" + String(row.role), stamp)
		return result

class MeasuredPolicy extends CropWorkerPolicy:
	var metrics: Dictionary = {"planting_usec": 0, "planting_calls": 0, "fertilizer_usec": 0, "fertilizer_calls": 0}
	func planting_task(row: Dictionary) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.planting_task(row)
		metrics.planting_calls += 1
		metrics.planting_usec += Time.get_ticks_usec() - started
		return result
	func fertilizer_task(cell: Vector2i, crop: Crop, item: ItemDefinition = null, sync_apiary: bool = true, worker_id: String = "crop") -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.fertilizer_task(cell, crop, item, sync_apiary, worker_id)
		metrics.fertilizer_calls += 1
		metrics.fertilizer_usec += Time.get_ticks_usec() - started
		return result

class MeasuredRepository extends LocalSaveRepository:
	var read_usec: int = 0
	func read_profile(profile: String) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.read_profile(profile)
		read_usec += Time.get_ticks_usec() - started
		return result

class MeasuredAdapter extends WorldStateAdapter:
	var budget_usec: int = 32000
	func restore_async(data: Dictionary, now: float) -> Dictionary:
		var result: Dictionary = _restore_checkpoint(data, now)
		if not result.ok:
			return result
		if budget_usec == 0:
			world.workers.advance(maxf(now, data.saved_at))
		else:
			await world.workers.advance_async(maxf(now, data.saved_at), budget_usec)
		return _finish_restore(maxf(now, data.saved_at), float(result.previous_simulation))
	var checkpoint_usec: int = 0
	var finish_usec: int = 0
	func _restore_checkpoint(data: Dictionary, now: float) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super._restore_checkpoint(data, now)
		checkpoint_usec += Time.get_ticks_usec() - started
		return result
	func _finish_restore(now: float, previous_simulation: float) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super._finish_restore(now, previous_simulation)
		finish_usec += Time.get_ticks_usec() - started
		return result

var _options: Dictionary = {}
var _gaps: Array[float] = []
var _last_frame: int = 0
var _first_frame: int = 0
var _updates: int = 0
var _previous_progress: float = 0.0
var _progress_monotonic: bool = true
var _progress_completed: bool = false

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(0, args.size() - 1, 2):
		_options[args[index]] = args[index + 1]
	_run.call_deferred()

func _heartbeat() -> void:
	var stamp: int = Time.get_ticks_usec()
	if _first_frame == 0:
		_first_frame = stamp
	_gaps.append(float(stamp - _last_frame) / 1000.0)
	_last_frame = stamp

func _progress(fraction: float) -> void:
	_updates += 1
	_progress_monotonic = _progress_monotonic and fraction >= _previous_progress and fraction >= 0.0 and fraction <= 1.0
	_previous_progress = fraction
	_progress_completed = is_equal_approx(fraction, 1.0)

func _write(result: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(String(_options["--result"]), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write benchmark result")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	get_tree().quit(0 if result.get("ok", false) else 1)

func _run() -> void:
	var source: String = String(_options["--source"])
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not envelope is Dictionary or not envelope.get("payload") is String:
		_write({"ok": false, "error": "Invalid source envelope"})
		return
	var raw: Variant = JSON.parse_string(envelope.payload)
	var began: int = Time.get_ticks_usec()
	var catalog: SaveCatalog = SaveCatalog.new()
	var catalog_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var checked: Dictionary = SaveSchema.validate(raw, catalog)
	if not checked.ok:
		_write({"ok": false, "error": str(checked)})
		return
	var data: Dictionary = checked.snapshot
	var target: float = float(data.saved_at) + float(_options["--gap"])
	TimeManager.clock_source = func() -> float: return float(data.saved_at)
	TimeManager._last_timestamp = float(data.saved_at)
	TimeManager.set_process(false)
	began = Time.get_ticks_usec()
	var world: FarmWorld = (load("res://world/main_world.tscn") as PackedScene).instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	# Deterministic setup: register authored physics before the load starts.
	await get_tree().physics_frame
	await get_tree().process_frame
	var scene_setup_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	TimeManager.clock_source = func() -> float: return target
	var repository: MeasuredRepository = MeasuredRepository.new(source.get_base_dir(), catalog)
	var adapter: MeasuredAdapter = MeasuredAdapter.new(world, catalog)
	adapter.budget_usec = int(_options.get("--budget", "32000"))
	var measured_bridge: MeasuredBridge = MeasuredBridge.new(world)
	world.workers.bridge = measured_bridge
	var measured_policy: MeasuredPolicy = MeasuredPolicy.new(world)
	world.workers.crop_policy = measured_policy
	var manager: GameSaveManager = GameSaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.catalog = catalog
	manager.repository = repository
	manager.adapter = adapter
	manager.profile_id = String(data.profile_id)
	world.workers.catch_up_progress.connect(_progress)
	_last_frame = Time.get_ticks_usec()
	began = _last_frame
	get_tree().process_frame.connect(_heartbeat)
	var result: Dictionary = await manager.load_game()
	var ended: int = Time.get_ticks_usec()
	get_tree().process_frame.disconnect(_heartbeat)
	_gaps.append(float(ended - _last_frame) / 1000.0)
	_gaps.sort()
	var restore_responsive_ms: float = float(ended - began) / 1000.0
	var ok: bool = bool(result.ok) and manager.writes_enabled and not manager.busy and _progress_monotonic and (_progress_completed or adapter.budget_usec == 0)
	ok = ok and is_equal_approx(world.workers.simulated_at, target) and TimeManager.simulation_timestamp == -1.0 and not TimeManager.is_processing() and world.process_mode == Node.PROCESS_MODE_DISABLED
	var state: Dictionary = adapter.capture(String(data.profile_id), int(data.revision), target)
	var state_file: FileAccess = FileAccess.open(String(_options["--result"]) + ".state.json", FileAccess.WRITE)
	state_file.store_string(JSON.stringify(state))
	state_file.close()
	_write({
		"ok": ok, "budget_usec": adapter.budget_usec, "engine": Engine.get_version_info().string, "renderer": DisplayServer.get_name(),
		"gap_seconds": float(_options["--gap"]),
		"catalog_ms": catalog_ms, "scene_setup_ms": scene_setup_ms,
		"load_game_ms": restore_responsive_ms,
		"read_validate_ms": float(repository.read_usec) / 1000.0,
		"checkpoint_ms": float(adapter.checkpoint_usec) / 1000.0,
		"final_sync_ms": float(adapter.finish_usec) / 1000.0,
		"other_load_including_workers_and_yields_ms": restore_responsive_ms - float(repository.read_usec + adapter.checkpoint_usec + adapter.finish_usec) / 1000.0,
		"first_process_frame_ms": float(_first_frame - began) / 1000.0,
		"frame_gap_max_ms": _gaps.back(), "frame_gap_p95_ms": _gaps[ceili(float(_gaps.size()) * 0.95) - 1],
		"sampled_frame_intervals": _gaps.size(), "progress_updates": _updates,
		"progress_monotonic": _progress_monotonic, "progress_completed": _progress_completed,
		"clock_and_process_state_restored": ok,
		"bridge_metrics": measured_bridge.metrics,
		"crop_policy_metrics": measured_policy.metrics,
		"counts": {"crops": data.crops.size(), "trees": data.trees.size(), "animals": data.animals.size(), "workers": data.workers.rows.size()},
		"note": "Headless process-frame timings are not native FPS or time to first visible frame. No profile is written."
	})
