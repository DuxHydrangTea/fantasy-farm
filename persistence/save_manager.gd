class_name GameSaveManager
extends Node
## Application service adapted from the Godot skill save_manager template.
## The repository owns IO; the adapter owns scene details. Replace repository
## with an HTTP implementation of save_repository.gd without changing gameplay.
signal status_changed(message: String, success: bool)
signal operation_finished
@export var autosave_seconds: float = 30.0
var profile_id: String = "local"
var revision: int = 0
var busy: bool = false
var writes_enabled: bool = false
var repository: SaveRepository
var local_directory: String = "user://saves"
var catalog: SaveCatalog
var adapter: WorldStateAdapter
var _elapsed: float = 0.0
var _closing: bool = false
var _quit_failed: bool = false
var _status_source: String = ""
var _status_error: Dictionary = {}
var _status_success: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind_world(world: FarmWorld, backend: SaveRepository = null, profile: String = "local") -> Dictionary:
	if busy or adapter != null:
		return SaveSchema.failure("Another world is already in use.", "busy")
	if not SaveSchema.identifier(profile):
		return SaveSchema.failure("Invalid profile ID.")
	catalog = SaveCatalog.new()
	repository = backend if backend != null else LocalSaveRepository.new(local_directory, catalog)
	adapter = WorldStateAdapter.new(world, catalog)
	profile_id = profile
	world.tree_exiting.connect(_unbind_world, CONNECT_ONE_SHOT)
	get_tree().auto_accept_quit = false
	return await load_game()

func _unbind_world() -> void:
	if adapter != null and is_instance_valid(adapter.world) and adapter.world.tool_upgrades != null:
		adapter.world.tool_upgrades.profile_ready = false
	adapter = null
	writes_enabled = false
	get_tree().auto_accept_quit = true

func _process(delta: float) -> void:
	if adapter == null or not writes_enabled or busy or _closing:
		return
	_elapsed += delta
	if _elapsed >= autosave_seconds:
		_elapsed = 0.0
		save_game()

# busy ngăn save/load chồng nhau; chỉ tăng revision sau khi backend xác nhận ghi thành công.
# Nếu tăng trước rồi ghi lỗi, lần sau client sẽ đòi revision không tồn tại và tự gây conflict.
# Khi conflict/corrupt/future_version, dừng tự lưu để không âm thầm ghi đè bản cần phục hồi.
# Không biến lỗi đọc/ghi thành game mới rồi lưu đè: đó là mất dữ liệu, không phải cách tự sửa an toàn.
func save_game() -> Dictionary:
	if adapter != null and adapter.world.workers != null and adapter.world.workers.busy:
		return SaveSchema.failure("A worker transaction is in progress.", "busy")
	if busy or adapter == null or not writes_enabled:
		return SaveSchema.failure("This profile cannot be saved yet.", "busy" if busy else "disabled")
	busy = true
	_sync_upgrade_readiness()
	var snapshot: Dictionary = adapter.capture(profile_id, revision + 1, _clock().now())
	var result: Dictionary = SaveSchema.validate(snapshot, catalog)
	if result.ok:
		result = await repository.write_profile_async(profile_id, result.snapshot, revision, true)
	if result.ok:
		revision = int(snapshot.revision)
		_elapsed = 0.0
		_quit_failed = false
	elif result.get("code") in ["conflict", "corrupt", "future_version"]:
		writes_enabled = false
	busy = false
	_sync_upgrade_readiness()
	_report_status("Progress saved" if result.ok else "Save failed: {error}", result.ok, result)
	operation_finished.emit()
	return result

func load_game() -> Dictionary:
	if busy or adapter == null:
		return SaveSchema.failure("This profile cannot be loaded yet.", "busy")
	busy = true
	_sync_upgrade_readiness()
	var scene: Node = adapter.world
	var old_mode: Node.ProcessMode = scene.process_mode
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var result: Dictionary = await repository.read_profile(profile_id)
	var recovered: bool = bool(result.get("recovered", false))
	if result.ok and result.get("found", false):
		var snapshot: Variant = result.get("snapshot")
		result = SaveSchema.validate(snapshot, catalog)
		if result.ok:
			snapshot = result.snapshot
		if result.ok and snapshot.profile_id != profile_id:
			result = SaveSchema.failure("The returned profile does not match.")
		if result.ok:
			result = adapter.preflight(snapshot)
		if result.ok:
			_clock().advance_floor(float(snapshot.saved_at))
			result = adapter.restore(snapshot, _clock().now())
			if result.ok:
				revision = int(snapshot.revision)
				result.recovered = recovered
	elif result.ok and revision != 0:
		# A file removed during play must not silently turn a load into "new game".
		result = SaveSchema.failure("The save file was deleted outside the game.", "missing")
	if is_instance_valid(scene):
		scene.process_mode = old_mode
	writes_enabled = bool(result.ok)
	busy = false
	_sync_upgrade_readiness()
	_elapsed = 0.0
	var message: String = "Progress loaded" if revision > 0 else "F5: save · F9: load · Autosave every 30 seconds"
	if result.get("recovered", false):
		message = "Backup restored"
	if not result.ok:
		message = "Load failed; autosave disabled: {error}"
	_report_status(message, result.ok, result)
	operation_finished.emit()
	return result

func _sync_upgrade_readiness() -> void:
	if adapter != null and is_instance_valid(adapter.world) and adapter.world.tool_upgrades != null:
		adapter.world.tool_upgrades.profile_ready = writes_enabled and not busy

func _clock() -> FarmClock:
	return TimeManager

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _status_source.is_empty():
		_emit_status()
	if adapter == null:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_with_save()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and writes_enabled and not busy and not _closing:
		save_game()

func _quit_with_save() -> void:
	if _closing:
		return
	_closing = true
	if busy:
		await operation_finished
	if _quit_failed or not writes_enabled:
		get_tree().quit()
		return
	var result: Dictionary = await save_game()
	if result.ok:
		get_tree().quit()
	else:
		_quit_failed = true
		_closing = false
		_report_status("Unable to save. Press F5 to retry; close again to quit without saving.", false)

func _report_status(source: String, success: bool, error: Dictionary = {}) -> void:
	_status_source = source
	_status_success = success
	_status_error = error.duplicate(true) if not success else {}
	_emit_status()

func _emit_status() -> void:
	status_changed.emit(tr(_status_source).format({"error": GameText.error(_status_error)}), _status_success)
