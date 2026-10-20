extends GutTest
var catalog: SaveCatalog
var repo: LocalSaveRepository
var folder: String

func before_each() -> void:
	catalog = SaveCatalog.new()
	folder = "res://.godot/save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	repo = LocalSaveRepository.new(folder, catalog)

func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var file: String = repo.path("test") + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	if DirAccess.dir_exists_absolute(folder):
		DirAccess.remove_absolute(folder)

func _snapshot(revision: int = 1) -> Dictionary:
	return {"version": SaveSchema.VERSION, "world_id": "main_world", "profile_id": "test", "revision": revision, "saved_at": 1000.0,
		"player": {"position": [32, 64], "facing": "down", "selected_slot": 0}, "inventory": [{"item": "hoe", "count": 1}],
		"soil": [], "crops": [], "animals": [], "troughs": [], "pickups": [], "flower_gardens": []}

func _write_raw(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func test_missing_profile_is_a_new_game() -> void:
	var result: Dictionary = repo.read_profile("test")
	assert_true(result.ok)
	assert_false(result.found)
	assert_eq(result.revision, 0)

func test_roundtrip_and_previous_revision_backup() -> void:
	assert_true(repo.write_profile("test", _snapshot(), 0).ok)
	var latest: Dictionary = _snapshot(2)
	latest.player.position = [100.5, 200.25]
	assert_true(repo.write_profile("test", latest, 1).ok)
	var result: Dictionary = repo.read_profile("test")
	assert_true(result.ok)
	assert_eq(int(result.snapshot.revision), 2)
	assert_eq(float(result.snapshot.player.position[0]), 100.5)
	assert_true(FileAccess.file_exists(repo.path("test") + ".bak"))

func test_truncated_primary_recovers_backup_and_can_save_again() -> void:
	repo.write_profile("test", _snapshot(), 0)
	repo.write_profile("test", _snapshot(2), 1)
	_write_raw(repo.path("test"), "{truncated")
	var result: Dictionary = repo.read_profile("test")
	assert_true(result.ok)
	assert_true(result.recovered)
	assert_eq(int(result.snapshot.revision), 1)
	assert_true(repo.write_profile("test", _snapshot(2), 1).ok)
	assert_eq(int(repo._read(repo.path("test") + ".bak", "test").snapshot.revision), 1)

func test_checksum_damage_is_detected() -> void:
	repo.write_profile("test", _snapshot(), 0)
	var file: FileAccess = FileAccess.open(repo.path("test"), FileAccess.READ)
	var source: String = file.get_as_text()
	file.close()
	_write_raw(repo.path("test"), source.replace("1000", "1001"))
	assert_false(repo.read_profile("test").ok)
	assert_false(repo.write_profile("test", _snapshot(), 0).ok, "Never overwrite unrecoverable corruption with a new game")

func test_stale_revision_does_not_overwrite_file() -> void:
	repo.write_profile("test", _snapshot(), 0)
	var result: Dictionary = repo.write_profile("test", _snapshot(), 0)
	assert_false(result.ok)
	assert_eq(result.code, "conflict")
	assert_eq(int(repo.read_profile("test").revision), 1)

func test_future_version_is_not_downgraded_to_backup() -> void:
	repo.write_profile("test", _snapshot(), 0)
	repo.write_profile("test", _snapshot(2), 1)
	var future: Dictionary = _snapshot(3)
	future.version = SaveSchema.VERSION + 1
	var payload: String = JSON.stringify(future)
	_write_raw(repo.path("test"), JSON.stringify({"format": "fantasy_farm_save", "payload": payload, "sha256": payload.sha256_text()}))
	var result: Dictionary = repo.read_profile("test")
	assert_false(result.ok)
	assert_eq(result.code, "future_version")
	assert_false(repo.write_profile("test", _snapshot(3), 2).ok)

func test_schema_rejects_unknown_resource_and_path_injection() -> void:
	var data: Dictionary = _snapshot()
	data.inventory[0].item = "res://items/tools/hoe.tres"
	assert_false(SaveSchema.validate(data, catalog).ok)
	assert_false(repo.read_profile("../other").ok)
	assert_false(repo.write_profile("other", _snapshot(), 0).ok)

func test_schema_rejects_invalid_numbers_types_and_duplicate_cells() -> void:
	var data: Dictionary = _snapshot()
	data.player.position = [NAN, 2]
	assert_false(SaveSchema.validate(data, catalog).ok)
	data = _snapshot()
	data.inventory[0].count = 0.5
	assert_false(SaveSchema.validate(data, catalog).ok)
	data = _snapshot()
	data.soil = [{"cell": [1, 2], "state": 1}, {"cell": [1, 2], "state": 2}]
	assert_false(SaveSchema.validate(data, catalog).ok)
	data.animals = [false]
	assert_false(SaveSchema.validate(data, catalog).ok)

func test_catalog_contains_all_current_gameplay_definitions() -> void:
	assert_eq(catalog.crops.size(), 22)
	assert_eq(catalog.animals.size(), 7)
	assert_true(catalog.items.has("cow_milk"))
	assert_true(catalog.items.has("sheep_wool"))
	assert_true(catalog.valid_skin("chicken", "rooster"))
	assert_false(catalog.valid_skin("sheep", "cow_01"))

func test_version_one_file_migrates_to_two_and_remains_a_valid_backup() -> void:
	var old: Dictionary = _snapshot()
	old.version = 1
	old.erase("flower_gardens")
	var payload: String = JSON.stringify(old)
	_write_raw(repo.path("test"), JSON.stringify({"format": "fantasy_farm_save", "payload": payload, "sha256": payload.sha256_text()}))
	var result: Dictionary = repo.read_profile("test")
	assert_true(result.ok)
	assert_eq(int(result.snapshot.version), SaveSchema.VERSION)
	assert_eq(result.snapshot.flower_gardens.size(), 0)
	assert_eq(result.snapshot.inventory[0].item, "hoe")
	assert_true(repo.write_profile("test", _snapshot(2), 1).ok)
	_write_raw(repo.path("test"), "damaged")
	result = repo.read_profile("test")
	assert_true(result.recovered)
	assert_eq(int(result.snapshot.version), SaveSchema.VERSION)
	assert_eq(int(result.snapshot.revision), 1)
