extends GutTest
const Profiles = preload("res://persistence/game_profiles.gd")
var folder: String
var profiles: RefCounted

func before_each() -> void:
	folder = "user://profile_tests_" + Crypto.new().generate_random_bytes(8).hex_encode()
	profiles = Profiles.new(folder)

func after_each() -> void:
	if DirAccess.dir_exists_absolute(folder):
		for filename: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)

func _write(id: String, coins: int = 1234) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var payload: String = JSON.stringify({"profile_id": id, "coins": coins, "land_columns": 12, "version": 36})
	var file: FileAccess = FileAccess.open(folder.path_join("profile_" + id + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": "fantasy_farm_save", "payload": payload, "sha256": payload.sha256_text()}))
	file.close()

func test_empty_directory_has_no_continue_and_blank_names_do_not_create_profiles() -> void:
	assert_eq(profiles.latest_profile(), "")
	assert_eq(profiles.list_profiles(), [])
	assert_false(profiles.create_profile("  ").ok)

func test_multiple_new_profiles_have_unique_ids_names_and_separate_save_files() -> void:
	var first: Dictionary = profiles.create_profile("Nông trại A")
	var second: Dictionary = profiles.create_profile("Nông trại B")
	assert_true(first.ok)
	assert_true(second.ok)
	assert_ne(first.id, second.id)
	_write(first.id, 100)
	_write(second.id, 200)
	var rows: Array[Dictionary] = profiles.list_profiles()
	assert_eq(rows.size(), 2)
	var balances: Dictionary = {}
	for row: Dictionary in rows:
		balances[row.name] = row.coins
	assert_eq(balances, {"Nông trại A": 100, "Nông trại B": 200})
	assert_eq(profiles.mark_played(first.id), OK)
	assert_eq(profiles.latest_profile(), first.id)
	assert_eq(profiles.mark_played(second.id), OK)
	assert_eq(profiles.latest_profile(), second.id)

func test_existing_local_profile_is_discovered_without_moving_it_or_listing_backups() -> void:
	_write("local", 1000000000)
	var path: String = folder.path_join("profile_local.json")
	var original: String = FileAccess.get_file_as_string(path)
	var file: FileAccess = FileAccess.open(folder.path_join("profile_local.before-test.json"), FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var rows: Array[Dictionary] = profiles.list_profiles()
	assert_eq(rows.size(), 1)
	assert_true(rows[0].legacy)
	assert_eq(rows[0].coins, 1000000000)
	assert_eq(profiles.latest_profile(), "local")
	assert_eq(FileAccess.get_file_as_string(path), original)

func test_corrupt_primary_can_use_backup_and_corrupt_only_slots_cannot_continue() -> void:
	_write("local")
	var path: String = folder.path_join("profile_local.json")
	assert_eq(DirAccess.copy_absolute(path, path + ".bak"), OK)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	assert_eq(profiles.latest_profile(), "local")
	DirAccess.remove_absolute(path + ".bak")
	assert_false(profiles.list_profiles()[0].valid)
	assert_eq(profiles.latest_profile(), "")
