extends GutTest
var catalog: SaveCatalog
var repo: LocalSaveRepository
var folder: String
var _async_finished: bool = false
var _async_result: Dictionary = {}

class SlowRepository extends LocalSaveRepository:
	func _commit_io(profile: String, data: Dictionary, expected_hash: String, primary_valid: bool) -> Dictionary:
		OS.delay_msec(150)
		return super._commit_io(profile, data, expected_hash, primary_valid)

class ChangedRepository extends LocalSaveRepository:
	func _commit_io(profile: String, data: Dictionary, expected_hash: String, primary_valid: bool) -> Dictionary:
		var outside: Dictionary = data.duplicate(true)
		outside.revision = 50
		var payload: String = JSON.stringify(outside)
		var file: FileAccess = FileAccess.open(path(profile), FileAccess.WRITE)
		file.store_string(JSON.stringify({"format": "fantasy_farm_save", "payload": payload, "sha256": payload.sha256_text()}))
		file.close()
		return super._commit_io(profile, data, expected_hash, primary_valid)

func _launch_async(data: Dictionary) -> void:
	_async_finished = false
	_async_result = await repo.write_profile_async("test", data, 0)
	_async_finished = true

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
	return {"version": SaveSchema.VERSION, "land_columns": 1, "coins": 1000, "world_id": "main_world", "profile_id": "test", "revision": revision, "saved_at": 1000.0,
		"player": {"position": [32, 64], "facing": "down", "selected_slot": 0}, "inventory": [{"item": "hoe", "count": 1}],
		"weather": WeatherSchedule.new().capture(), "trees": [], "beehives": [], "soil": [], "crops": [], "animals": [], "troughs": [], "pickups": [], "flower_gardens": []}

func _write_raw(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func test_v3_coins_migrate_once_and_current_coin_values_are_validated() -> void:
	var old: Dictionary = _snapshot()
	old.version = 3
	old.erase("coins")
	var migrated: Dictionary = SaveSchema.validate(old, catalog)
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.coins, 1000)
	assert_false(old.has("coins"))
	migrated.snapshot.coins = 0
	assert_eq(SaveSchema.validate(migrated.snapshot, catalog).snapshot.coins, 0)
	for invalid: Variant in [-1, 0.5, "1000", WalletComponent.MAX_COINS + 1]:
		var bad: Dictionary = _snapshot()
		bad.coins = invalid
		assert_false(SaveSchema.validate(bad, catalog).ok)
	var missing: Dictionary = _snapshot()
	missing.erase("coins")
	assert_false(SaveSchema.validate(missing, catalog).ok)

func test_missing_profile_is_a_new_game() -> void:
	var result: Dictionary = repo.read_profile("test")
	assert_true(result.ok)
	assert_false(result.found)
	assert_eq(result.revision, 0)

func test_v4_bag_expands_without_mutation_and_preserves_money_hotbar_and_stacks() -> void:
	var old: Dictionary = _snapshot()
	old.version = 4
	old.coins = 731
	old.player.selected_slot = 5
	old.inventory = []
	for index: int in range(24):
		old.inventory.append({"item": "hoe", "count": 1})
	old.inventory[5] = {"item": "cow_milk", "count": 234}
	var original: String = JSON.stringify(old)
	var checked: Dictionary = SaveSchema.validate(old, catalog)
	assert_true(checked.ok)
	assert_eq(JSON.stringify(old), original)
	assert_eq(checked.snapshot.inventory.size(), 64)
	assert_eq(checked.snapshot.inventory.slice(0, 24), old.inventory)
	assert_eq(checked.snapshot.coins, 731)
	assert_eq(checked.snapshot.player.selected_slot, 5)
	for index: int in range(24, 64):
		assert_eq(checked.snapshot.inventory[index], {"item": "", "count": 0})
	var again: Dictionary = SaveSchema.validate(checked.snapshot, catalog)
	assert_eq(again.snapshot, checked.snapshot, "Migration only runs once")
	assert_true(repo.write_profile("test", checked.snapshot, 0).ok)
	assert_eq(repo.read_profile("test").snapshot.inventory.size(), 64)

func test_v4_bag_migration_does_not_hide_invalid_items_or_resize_custom_fixtures() -> void:
	var old: Dictionary = _snapshot()
	old.version = 4
	assert_eq(SaveSchema.validate(old, catalog).snapshot.inventory.size(), 1)
	old.version = SaveSchema.VERSION
	old.inventory = []
	for index: int in range(24):
		old.inventory.append({"item": "hoe", "count": 1})
	var current_legacy: Dictionary = SaveSchema.validate(old, catalog)
	assert_true(current_legacy.ok)
	assert_eq(current_legacy.snapshot.inventory.size(), 64, "Live reload can still write an old-sized bag")
	assert_eq(old.inventory.size(), 24)
	old.inventory = []
	for index: int in range(24):
		old.inventory.append({"item": "unknown_item", "count": 1})
	assert_false(SaveSchema.validate(old, catalog).ok)

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

func test_version_one_file_migrates_to_current_and_remains_a_valid_backup() -> void:
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

func test_dense_garden_file_roundtrip_accepts_all_180_planted_pots() -> void:
	var saved: Dictionary = _snapshot()
	var flowers: Array = []
	for y: int in range(10):
		for x: int in range(18):
			flowers.append({"cell": [x, y], "flower": "flower_01", "planted_at": 1000.0, "growth_started_at": -1.0, "matures_at": 0.0, "progress": 0.0})
	saved.flower_gardens = [{"id": "flower_garden_01", "flowers": flowers, "starter_flowers_added": true}]
	assert_true(repo.write_profile("test", saved, 0).ok)
	var read: Dictionary = repo.read_profile("test")
	assert_true(read.ok)
	assert_eq(read.snapshot.flower_gardens[0].flowers.size(), 180)
	assert_eq(read.snapshot.flower_gardens[0].flowers[-1].cell, [17.0, 9.0])

func test_version_two_garden_migration_is_complete_and_does_not_mutate_input() -> void:
	var saved: Dictionary = _snapshot()
	saved.version = 2
	var flowers: Array = []
	for y: int in range(6):
		for x: int in range(10):
			flowers.append({"cell": [x, y], "flower": "flower_01", "planted_at": 900.0, "growth_started_at": 900.0, "matures_at": 1020.0, "progress": 0.5})
	saved.flower_gardens = [{"id": "flower_garden_01", "flowers": flowers, "starter_flowers_added": true}]
	var original: String = JSON.stringify(saved)
	var checked: Dictionary = SaveSchema.validate(saved, catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.version, SaveSchema.VERSION)
	assert_eq(JSON.stringify(saved), original)
	var mapped: Dictionary = {}
	for row: Dictionary in checked.snapshot.flower_gardens[0].flowers:
		assert_false(mapped.has(str(row.cell)))
		mapped[str(row.cell)] = true
		assert_eq(row.progress, 0.5)
		assert_eq(row.matures_at, 1020.0)
	assert_eq(mapped.size(), 60)
	assert_eq(checked.snapshot.flower_gardens[0].flowers[-1].cell, [17, 9])
	assert_eq(checked.snapshot.inventory, saved.inventory)
	assert_eq(checked.snapshot.player, saved.player)
	var second: Dictionary = SaveSchema.validate(checked.snapshot, catalog)
	assert_eq(second.snapshot, checked.snapshot, "Migration cannot run twice")

func test_version_two_invalid_garden_coordinate_cannot_become_a_valid_dense_slot() -> void:
	var saved: Dictionary = _snapshot()
	saved.version = 2
	saved.flower_gardens = [{"id": "flower_garden_01", "flowers": [{"cell": [0, 6], "flower": "flower_01", "planted_at": 1000.0, "growth_started_at": -1.0, "matures_at": 0.0, "progress": 0.0}]}]
	assert_false(SaveSchema.validate(saved, catalog).ok)

func test_async_save_roundtrip_recovery_and_revision_guard() -> void:
	assert_true((await repo.write_profile_async("test", _snapshot(), 0)).ok)
	assert_gte(repo.worker_operations, 2)
	assert_true((await repo.write_profile_async("test", _snapshot(2), 1)).ok)
	_write_raw(repo.path("test"), "corrupt")
	assert_true((await repo.write_profile_async("test", _snapshot(2), 1)).ok)
	assert_eq(int(repo.read_profile("test").revision), 2)
	assert_eq(int(repo._read(repo.path("test") + ".bak", "test").revision), 1)
	var conflict: Dictionary = await repo.write_profile_async("test", _snapshot(2), 1)
	assert_false(conflict.ok)
	assert_eq(conflict.code, "conflict")

func test_async_save_keeps_main_frames_running_rejects_overlap_and_freezes_dto() -> void:
	repo = SlowRepository.new(folder, catalog)
	var data: Dictionary = _snapshot()
	_launch_async(data)
	data.inventory[0].count = 0
	var overlap: Dictionary = await repo.write_profile_async("test", _snapshot(), 0)
	assert_eq(overlap.code, "busy")
	assert_eq(repo.write_profile("test", _snapshot(), 0).code, "busy")
	var frames: int = 0
	var started: int = Time.get_ticks_msec()
	while not _async_finished and Time.get_ticks_msec() - started < 4000:
		await get_tree().process_frame
		frames += 1
	assert_true(_async_finished)
	assert_true(_async_result.ok)
	assert_gt(frames, 1, "Disk latency cannot block rendering/input frames")
	assert_eq(int(repo.read_profile("test").snapshot.inventory[0].count), 1)

func test_async_save_detects_external_change_between_validation_and_commit() -> void:
	assert_true(repo.write_profile("test", _snapshot(), 0).ok)
	repo = ChangedRepository.new(folder, catalog)
	var result: Dictionary = await repo.write_profile_async("test", _snapshot(2), 1)
	assert_false(result.ok)
	assert_eq(result.code, "conflict")
	assert_eq(int(repo.read_profile("test").revision), 50)

func test_async_save_rejects_future_version_and_resource_objects_without_overwriting() -> void:
	var future: Dictionary = _snapshot()
	future.version = SaveSchema.VERSION + 1
	var payload: String = JSON.stringify(future)
	_write_raw(repo.path("test"), JSON.stringify({"format": "fantasy_farm_save", "payload": payload, "sha256": payload.sha256_text()}))
	assert_eq((await repo.write_profile_async("test", _snapshot(), 0)).code, "future_version")
	var data: Dictionary = _snapshot()
	data.extra = Node.new()
	assert_false((await repo.write_profile_async("test", data, 0)).ok)
	data.extra.free()
