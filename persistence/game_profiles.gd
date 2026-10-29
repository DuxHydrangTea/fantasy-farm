class_name GameProfiles
extends RefCounted
## Lightweight profile index. Full game validation stays in LocalSaveRepository.
var directory: String

func _init(folder: String = "user://saves") -> void:
	directory = folder

func _index() -> ConfigFile:
	var data: ConfigFile = ConfigFile.new()
	data.load(directory.path_join("profiles.cfg"))
	return data

func _store(data: ConfigFile) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var path: String = directory.path_join("profiles.cfg")
	error = data.save(path + ".tmp")
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func create_profile(title: String) -> Dictionary:
	var data: ConfigFile = _index()
	var id: String = "farm_" + Crypto.new().generate_random_bytes(12).hex_encode()
	var caption: String = title.strip_edges().left(48)
	if caption.is_empty():
		return {"ok": false, "error": "Enter a farm name."}
	data.set_value(id, "name", caption)
	data.set_value(id, "created_at", Time.get_unix_time_from_system())
	data.set_value(id, "last_played", 0.0)
	var error: Error = _store(data)
	return {"ok": error == OK, "id": id, "error": "Unable to create the farm." if error != OK else ""}

func mark_played(id: String) -> Error:
	if not id.is_valid_identifier():
		return ERR_INVALID_PARAMETER
	var data: ConfigFile = _index()
	data.set_value("session", "last_profile", id)
	data.set_value(id, "last_played", Time.get_unix_time_from_system())
	return _store(data)

func _summary(path: String, id: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("format") != "fantasy_farm_save" or not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return {}
	if String(envelope.payload).sha256_text() != envelope.sha256:
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var payload: Variant = parser.data
	if not payload is Dictionary or payload.get("profile_id") != id or not payload.get("coins") is float and not payload.get("coins") is int:
		return {}
	if not is_finite(float(payload.coins)) or float(payload.coins) < 0:
		return {}
	for key: String in ["land_columns", "version"]:
		var value: Variant = payload.get(key, 0)
		if not (value is int or value is float) or not is_finite(float(value)):
			return {}
	return {"coins": int(payload.coins), "land_columns": int(payload.get("land_columns", 1)), "version": int(payload.get("version", 0))}

func list_profiles() -> Array[Dictionary]:
	var data: ConfigFile = _index()
	var ids: Dictionary = {}
	if not DirAccess.dir_exists_absolute(directory):
		return []
	for filename: String in DirAccess.get_files_at(directory):
		if not filename.begins_with("profile_"):
			continue
		var base: String = filename.trim_suffix(".bak")
		if not base.ends_with(".json"):
			continue
		var id: String = base.trim_prefix("profile_").trim_suffix(".json")
		if id.is_valid_identifier():
			ids[id] = true
	var rows: Array[Dictionary] = []
	for id: String in ids:
		var path: String = directory.path_join("profile_" + id + ".json")
		var summary: Dictionary = _summary(path, id)
		if summary.is_empty():
			summary = _summary(path + ".bak", id)
		var modified: float = float(FileAccess.get_modified_time(path))
		var title: String = String(data.get_value(id, "name", ""))
		rows.append({"id": id, "name": title, "legacy": id == "local" and title.is_empty(), "last_played": float(data.get_value(id, "last_played", modified)), "valid": not summary.is_empty(), "coins": int(summary.get("coins", 0)), "land_columns": int(summary.get("land_columns", 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.last_played > b.last_played if a.last_played != b.last_played else String(a.id) < String(b.id))
	return rows

func latest_profile() -> String:
	var rows: Array[Dictionary] = list_profiles()
	var last: String = String(_index().get_value("session", "last_profile", ""))
	for row: Dictionary in rows:
		if row.id == last and row.valid:
			return last
	for row: Dictionary in rows:
		if row.valid:
			return row.id
	return ""
