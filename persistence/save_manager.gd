extends Node
## Application service adapted from the Godot skill save_manager template.
## The repository owns IO; the adapter owns scene details. Replace repository
## with an HTTP implementation of save_repository.gd without changing gameplay.
signal status_changed(message: String, success: bool)
signal operation_finished
const Catalog = preload("res://persistence/save_catalog.gd")
const Repository = preload("res://persistence/save_repository.gd")
const LocalRepository = preload("res://persistence/local_save_repository.gd")
const Adapter = preload("res://persistence/world_state_adapter.gd")
const Schema = preload("res://persistence/save_schema.gd")
@export var autosave_seconds: float = 30.0
var profile_id: String = "local"
var revision: int = 0
var busy: bool = false
var writes_enabled: bool = false
var repository: Repository
var local_directory: String = "user://saves"
var catalog: Catalog
var adapter: Adapter
var _elapsed: float = 0.0
var _closing: bool = false
var _quit_failed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind_world(world: Node, backend: Repository = null, profile: String = "local") -> Dictionary:
	if busy or adapter != null:
		return Schema.failure("Một thế giới khác đang được sử dụng.", "busy")
	if not Schema.identifier(profile):
		return Schema.failure("ID hồ sơ không hợp lệ.")
	catalog = Catalog.new()
	repository = backend if backend != null else LocalRepository.new(local_directory, catalog)
	adapter = Adapter.new(world, catalog)
	profile_id = profile
	world.tree_exiting.connect(_unbind_world, CONNECT_ONE_SHOT)
	get_tree().auto_accept_quit = false
	return await load_game()

func _unbind_world() -> void:
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

func save_game() -> Dictionary:
	if busy or adapter == null or not writes_enabled:
		return Schema.failure("Chưa thể lưu hồ sơ này.", "busy" if busy else "disabled")
	busy = true
	var snapshot: Dictionary = adapter.capture(profile_id, revision + 1, _clock().now())
	var result: Dictionary = Schema.validate(snapshot, catalog)
	if result.ok:
		result = await repository.write_profile(profile_id, snapshot, revision)
	if result.ok:
		revision = int(snapshot.revision)
		_elapsed = 0.0
		_quit_failed = false
	elif result.get("code") in ["conflict", "corrupt", "future_version"]:
		writes_enabled = false
	busy = false
	status_changed.emit("Đã lưu tiến trình" if result.ok else "Lưu thất bại: " + String(result.error), result.ok)
	operation_finished.emit()
	return result

func load_game() -> Dictionary:
	if busy or adapter == null:
		return Schema.failure("Chưa thể tải hồ sơ này.", "busy")
	busy = true
	var scene: Node = adapter.world
	var old_mode: Node.ProcessMode = scene.process_mode
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var result: Dictionary = await repository.read_profile(profile_id)
	var recovered: bool = bool(result.get("recovered", false))
	if result.ok and result.get("found", false):
		var snapshot: Variant = result.get("snapshot")
		result = Schema.validate(snapshot, catalog)
		if result.ok:
			snapshot = result.snapshot
		if result.ok and snapshot.profile_id != profile_id:
			result = Schema.failure("Hồ sơ trả về không khớp.")
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
		result = Schema.failure("File lưu đã bị xóa bên ngoài game.", "missing")
	if is_instance_valid(scene):
		scene.process_mode = old_mode
	writes_enabled = bool(result.ok)
	busy = false
	_elapsed = 0.0
	var message: String = "Đã tải tiến trình" if revision > 0 else "F5: lưu · F9: tải · Tự lưu mỗi 30 giây"
	if result.get("recovered", false):
		message = "Đã khôi phục bản dự phòng"
	if not result.ok:
		message = "Tải thất bại; đã tắt tự lưu: " + String(result.error)
	status_changed.emit(message, result.ok)
	operation_finished.emit()
	return result

func _clock() -> Node:
	return get_node("/root/TimeManager")

func _notification(what: int) -> void:
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
		status_changed.emit("Không lưu được. F5 để thử lại; đóng lần nữa để thoát không lưu.", false)
