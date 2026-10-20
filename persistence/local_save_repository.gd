class_name LocalSaveRepository
extends SaveRepository
## Adapted from the Godot skill save_manager template: checked temp write,
## last-good backup and revision guard. Checksum detects damage, not cheating.
const MAX_BYTES: int = 8 * 1024 * 1024
var directory: String = "user://saves"
var catalog: SaveCatalog

func _init(folder: String = "user://saves", resources: SaveCatalog = null) -> void:
	directory = folder
	catalog = resources if resources != null else SaveCatalog.new()

func path(profile: String) -> String:
	return directory.path_join("profile_" + profile + ".json")

func read_profile(profile: String) -> Dictionary:
	if not SaveSchema.identifier(profile):
		return SaveSchema.failure("ID hồ sơ không hợp lệ.")
	var primary: Dictionary = _read(path(profile), profile)
	if primary.ok or primary.get("code") == "future_version":
		return primary
	var backup: Dictionary = _read(path(profile) + ".bak", profile)
	if backup.ok:
		backup.recovered = true
		return backup
	if primary.get("code") == "missing" and backup.get("code") == "missing":
		return {"ok": true, "found": false, "revision": 0}
	return backup if backup.get("code") == "future_version" else SaveSchema.failure("File lưu và bản dự phòng đều không đọc được. Giữ nguyên file để phục hồi.", "corrupt")

func _read(file_path: String, profile: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return SaveSchema.failure("Chưa có file lưu.", "missing")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return SaveSchema.failure("Không mở được file lưu.", "io")
	if file.get_length() > MAX_BYTES:
		return SaveSchema.failure("File lưu quá lớn.")
	var source: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(source) != OK or not json.data is Dictionary:
		return SaveSchema.failure("File JSON bị hỏng.")
	var envelope: Dictionary = json.data
	if envelope.get("format") != "fantasy_farm_save" or not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text() != envelope.sha256:
		return SaveSchema.failure("Checksum file lưu không đúng.")
	if json.parse(envelope.payload) != OK:
		return SaveSchema.failure("Nội dung file lưu bị hỏng.")
	var checked: Dictionary = SaveSchema.validate(json.data, catalog)
	if not checked.ok:
		return checked
	if checked.snapshot.profile_id != profile:
		return SaveSchema.failure("File thuộc hồ sơ khác.")
	return {"ok": true, "found": true, "snapshot": checked.snapshot, "revision": int(checked.snapshot.revision), "recovered": false}

func write_profile(profile: String, snapshot: Dictionary, expected_revision: int) -> Dictionary:
	var checked: Dictionary = SaveSchema.validate(snapshot, catalog)
	if not checked.ok:
		return checked
	snapshot = checked.snapshot
	if snapshot.profile_id != profile or int(snapshot.revision) != expected_revision + 1:
		return SaveSchema.failure("Revision hoặc hồ sơ không khớp.", "conflict")
	var current: Dictionary = read_profile(profile)
	if not current.ok:
		return current
	if int(current.revision) != expected_revision:
		return SaveSchema.failure("File đã được cập nhật. Tải lại trước khi lưu.", "conflict")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return SaveSchema.failure("Không tạo được thư mục lưu: " + error_string(error), "io")
	var target: String = path(profile)
	var temp: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return SaveSchema.failure("Không ghi được file tạm.", "io")
	var payload: String = JSON.stringify(snapshot)
	file.store_string(JSON.stringify({"format": "fantasy_farm_save", "sha256": payload.sha256_text(), "payload": payload}, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read(temp, profile).ok:
		return SaveSchema.failure("Ghi file tạm không hoàn tất.", "io")
	# Never rotate a damaged primary over the last-good backup.
	if _read(target, profile).ok:
		if FileAccess.file_exists(target + ".bak"):
			error = DirAccess.remove_absolute(target + ".bak")
			if error != OK:
				return SaveSchema.failure("Không thay được bản dự phòng.", "io")
		error = DirAccess.rename_absolute(target, target + ".bak")
		if error != OK:
			return SaveSchema.failure("Không tạo được bản dự phòng.", "io")
	elif FileAccess.file_exists(target):
		error = DirAccess.remove_absolute(target)
		if error != OK:
			return SaveSchema.failure("Không thay được file lưu hỏng.", "io")
	error = DirAccess.rename_absolute(temp, target)
	if error != OK:
		return SaveSchema.failure("Không hoàn tất đổi file lưu; bản dự phòng được giữ lại.", "io")
	return {"ok": true, "revision": int(snapshot.revision)}
