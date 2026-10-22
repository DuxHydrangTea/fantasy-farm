class_name LocalSaveRepository
extends SaveRepository
## Adapted from the Godot skill save_manager template: checked temp write,
## last-good backup and revision guard. Checksum detects damage, not cheating.
const MAX_BYTES: int = 8 * 1024 * 1024
var directory: String = "user://saves"
var catalog: SaveCatalog
var _async_busy: bool = false
var worker_operations: int = 0

func _init(folder: String = "user://saves", resources: SaveCatalog = null) -> void:
	directory = folder
	catalog = resources if resources != null else SaveCatalog.new()

func path(profile: String) -> String:
	return directory.path_join("profile_" + profile + ".json")

# Phục hồi backup chỉ khi primary lỗi/mất. Nếu primary thuộc phiên bản game tương lai,
# phải từ chối thay vì lùi về backup cũ: lưu lại bằng game cũ có thể mất dữ liệu tính năng mới.
# Đây là bảo vệ tương thích dữ liệu, không phải tối ưu có thể bỏ mà không đổi hành vi.
func read_profile(profile: String) -> Dictionary:
	if not SaveSchema.identifier(profile):
		return SaveSchema.failure("Invalid profile ID.")
	var primary: Dictionary = _read(path(profile), profile)
	if primary.ok or primary.get("code") == "future_version":
		return primary
	var backup: Dictionary = _read(path(profile) + ".bak", profile)
	if backup.ok:
		backup.recovered = true
		return backup
	if primary.get("code") == "missing" and backup.get("code") == "missing":
		return {"ok": true, "found": false, "revision": 0}
	return backup if backup.get("code") == "future_version" else SaveSchema.failure("The save and backup cannot be read. Files kept for recovery.", "corrupt")

func _read(file_path: String, profile: String) -> Dictionary:
	return _validate_raw(_read_raw(file_path), profile)

func _validate_raw(raw: Dictionary, profile: String) -> Dictionary:
	if not raw.ok:
		return raw
	var checked: Dictionary = SaveSchema.validate(raw.snapshot, catalog)
	if not checked.ok:
		return checked
	if checked.snapshot.profile_id != profile:
		return SaveSchema.failure("This file belongs to another profile.")
	return {"ok": true, "found": true, "snapshot": checked.snapshot, "revision": int(checked.snapshot.revision), "recovered": false}

# File bọc nguyên chuỗi payload cùng SHA-256 của chính chuỗi đó để phát hiện hỏng/cắt cụt.
# Không parse rồi stringify lại trước khi đối chiếu, vì thứ tự key/khoảng trắng có thể đổi hash.
# Checksum này KHÔNG chống sửa save: ai sửa payload cũng có thể tính lại SHA-256.
# Giới hạn byte bảo vệ bộ đọc khỏi file quá lớn; catalog/schema còn được kiểm tra ở bước main thread.
func _read_raw(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return SaveSchema.failure("No save file yet.", "missing")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return SaveSchema.failure("Unable to open the save file.", "io")
	if file.get_length() > MAX_BYTES:
		return SaveSchema.failure("The save file is too large.")
	var source: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(source) != OK or not json.data is Dictionary:
		return SaveSchema.failure("The JSON file is corrupt.").merged({"file_hash": source.sha256_text()})
	var envelope: Dictionary = json.data
	if envelope.get("format") != "fantasy_farm_save" or not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text() != envelope.sha256:
		return SaveSchema.failure("The save checksum does not match.").merged({"file_hash": source.sha256_text()})
	if json.parse(envelope.payload) != OK:
		return SaveSchema.failure("The save contents are corrupt.").merged({"file_hash": source.sha256_text()})
	return {"ok": true, "snapshot": json.data, "file_hash": source.sha256_text()}

func write_profile(profile: String, snapshot: Dictionary, expected_revision: int) -> Dictionary:
	if _async_busy:
		return SaveSchema.failure("This profile is being saved.", "busy")
	var checked: Dictionary = SaveSchema.validate(snapshot, catalog)
	if not checked.ok:
		return checked
	snapshot = checked.snapshot
	if snapshot.profile_id != profile or int(snapshot.revision) != expected_revision + 1:
		return SaveSchema.failure("Revision or profile does not match.", "conflict")
	var current: Dictionary = read_profile(profile)
	if not current.ok:
		return current
	if int(current.revision) != expected_revision:
		return SaveSchema.failure("This file was updated. Load it before saving.", "conflict")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return SaveSchema.failure("Unable to create the save directory: {reason}", "io", {"reason": error_string(error)})
	var target: String = path(profile)
	var temp: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return SaveSchema.failure("Unable to write the temporary file.", "io")
	var payload: String = JSON.stringify(snapshot)
	file.store_string(JSON.stringify({"format": "fantasy_farm_save", "sha256": payload.sha256_text(), "payload": payload}, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read(temp, profile).ok:
		return SaveSchema.failure("The temporary file was not fully written.", "io")
	# Never rotate a damaged primary over the last-good backup.
	if current.get("found", false) and not current.get("recovered", false):
		if FileAccess.file_exists(target + ".bak"):
			error = DirAccess.remove_absolute(target + ".bak")
			if error != OK:
				return SaveSchema.failure("Unable to replace the backup.", "io")
		error = DirAccess.rename_absolute(target, target + ".bak")
		if error != OK:
			return SaveSchema.failure("Unable to create the backup.", "io")
	elif FileAccess.file_exists(target):
		error = DirAccess.remove_absolute(target)
		if error != OK:
			return SaveSchema.failure("Unable to replace the corrupt save.", "io")
	error = DirAccess.rename_absolute(temp, target)
	if error != OK:
		return SaveSchema.failure("Unable to replace the save file; backup kept.", "io")
	return {"ok": true, "revision": int(snapshot.revision)}

# Worker làm IO/JSON/hash; main thread nhường từng process_frame trong lúc chờ, rồi join lấy kết quả.
# Nếu gọi wait_to_finish ngay mà không chờ như trên, main thread sẽ bị chặn và autosave gây khựng.
# Không truy cập Node, UI hoặc duyệt Resource/catalog từ worker: đó là trạng thái của scene/main thread.
# Có thể thay cơ chế thread bằng backend async khác; yêu cầu cần giữ là không race dữ liệu sống.
func _run_io(work: Callable) -> Dictionary:
	var worker: Thread = Thread.new()
	var started: Error = worker.start(work)
	if started != OK:
		return SaveSchema.failure("Unable to start the save thread: {reason}", "io", {"reason": error_string(started)})
	worker_operations += 1
	while worker.is_alive():
		await (Engine.get_main_loop() as SceneTree).process_frame
	return worker.wait_to_finish() as Dictionary

func _primitive(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _primitive(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for child: Variant in value:
			if not _primitive(child, depth + 1):
				return false
		return true
	return typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]

func write_profile_async(profile: String, snapshot: Dictionary, expected_revision: int, pre_validated: bool = false) -> Dictionary:
	if _async_busy:
		return SaveSchema.failure("This profile is being saved.", "busy")
	var checked: Dictionary = {"ok": true, "snapshot": snapshot} if pre_validated else SaveSchema.validate(snapshot, catalog)
	if not checked.ok:
		return checked
	snapshot = checked.snapshot
	if snapshot.profile_id != profile or int(snapshot.revision) != expected_revision + 1:
		return SaveSchema.failure("Revision or profile does not match.", "conflict")
	if not _primitive(snapshot):
		return SaveSchema.failure("Save files accept only primitive data.")
	# Chụp sâu DTO TRƯỚC await đầu tiên. Trong thời gian chờ worker, game vẫn tiếp tục:
	# player có thể nhặt đồ, mua hàng hoặc caller sửa Dictionary/Array ban đầu.
	# Nếu worker dùng cùng cấu trúc có thể đổi, file có nguy cơ trộn inventory ở hai thời điểm.
	# _async_busy chặn hai lần ghi trong cùng repository giẫm lên chung file .tmp/.bak.
	snapshot = snapshot.duplicate(true)
	_async_busy = true
	# Resources/catalog validation stays on the main thread. Only plain DTOs and
	# filesystem/hash/JSON operations cross the worker boundary.
	var primary_raw: Dictionary = await _run_io(_read_raw.bind(path(profile)))
	var current: Dictionary = _validate_raw(primary_raw, profile)
	var primary_valid: bool = current.ok
	if not current.ok and current.get("code") != "future_version":
		var backup_raw: Dictionary = await _run_io(_read_raw.bind(path(profile) + ".bak"))
		current = _validate_raw(backup_raw, profile)
		if not current.ok and primary_raw.get("code") == "missing" and backup_raw.get("code") == "missing":
			current = {"ok": true, "revision": 0}
		elif not current.ok and current.get("code") != "future_version":
			current = SaveSchema.failure("The save and backup cannot be read.", "corrupt")
	if current.ok and int(current.revision) != expected_revision:
		current = SaveSchema.failure("This file was updated. Load it before saving.", "conflict")
	var result: Dictionary = current
	if current.ok:
		result = await _run_io(_commit_io.bind(profile, snapshot, String(primary_raw.get("file_hash", "")), primary_valid))
	_async_busy = false
	return result

# Kiểm tra revision trước commit giúp phát hiện đang lưu đè lên bản tiến trình mới hơn.
# So hash raw một lần nữa bắt thay đổi file trong khoảng giữa đọc/validate và ghi.
# Đây chưa phải khóa/transaction đa process hoàn chỉnh: vẫn có một cửa sổ race sau phép kiểm tra.
# Khi online cần CAS/transaction ở server, không được xem kiểm tra local này là đảm bảo đồng thời tuyệt đối.
# Tiếp theo ghi/flush/đọc xác nhận .tmp trước, rồi mới xoay primary hợp lệ sang .bak và đổi tên .tmp.
# Nếu ghi thẳng primary, mất điện/ổ đầy giữa chừng có thể phá bản lưu đang tốt.
# Nếu primary đang hỏng, không dùng nó ghi đè .bak tốt vừa dùng để phục hồi.
func _commit_io(profile: String, snapshot: Dictionary, expected_hash: String, primary_valid: bool) -> Dictionary:
	var target: String = path(profile)
	if FileAccess.file_exists(target):
		if expected_hash.is_empty() or FileAccess.get_file_as_string(target).sha256_text() != expected_hash:
			return SaveSchema.failure("The file changed while saving.", "conflict")
	elif not expected_hash.is_empty():
		return SaveSchema.failure("The file was deleted while saving.", "conflict")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return SaveSchema.failure("Unable to create the save directory.", "io")
	var temp: String = target + ".tmp"
	var payload: String = JSON.stringify(snapshot)
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return SaveSchema.failure("Unable to write the temporary file.", "io")
	file.store_string(JSON.stringify({"format": "fantasy_farm_save", "sha256": payload.sha256_text(), "payload": payload}, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read_raw(temp).ok:
		return SaveSchema.failure("The temporary file was not fully written.", "io")
	# Only a primary validated on the main thread may replace the last-good backup.
	if primary_valid:
		if FileAccess.file_exists(target + ".bak"):
			error = DirAccess.remove_absolute(target + ".bak")
		if error == OK:
			error = DirAccess.rename_absolute(target, target + ".bak")
	elif FileAccess.file_exists(target):
		error = DirAccess.remove_absolute(target)
	if error == OK:
		error = DirAccess.rename_absolute(temp, target)
	if error != OK:
		return SaveSchema.failure("Unable to finish saving; backup kept.", "io")
	return {"ok": true, "revision": int(snapshot.revision)}
