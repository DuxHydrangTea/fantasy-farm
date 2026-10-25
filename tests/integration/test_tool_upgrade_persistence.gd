extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var adapter: WorldStateAdapter
var _save_result: Dictionary = {}

class MemoryRepository extends SaveRepository:
	signal release_write
	var snapshot: Dictionary = {}
	var fail_read: bool = false
	var hold_write: bool = false
	func read_profile(_profile: String) -> Dictionary:
		if fail_read:
			return {"ok": false, "code": "corrupt", "error": "Test read failure"}
		return {"ok": true, "found": not snapshot.is_empty(), "snapshot": snapshot.duplicate(true), "revision": snapshot.get("revision", 0)}
	func write_profile(_profile: String, data: Dictionary, _expected: int) -> Dictionary:
		if hold_write:
			await release_write
		snapshot = data.duplicate(true)
		return {"ok": true, "revision": data.revision}

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())
	_save_result = {}

func _snapshot() -> Dictionary:
	return adapter.capture("tool_upgrade_test", 1, world.farming.time_manager.now())

func _enable_harness() -> void:
	world.tool_upgrades.profile_ready = true
	world.tool_upgrades.purchasing_enabled = true
	world.player.wallet.set_balance(500000)
	world.land.state.restore_columns(7, 4)

func test_world_composition_enables_feature_but_waits_for_profile_load() -> void:
	assert_not_null(world.tool_upgrades)
	assert_true(world.tool_upgrades.purchasing_enabled)
	assert_false(world.tool_upgrades.profile_ready)
	assert_eq(world.tool_upgrade_state.capture(), ToolUpgradeState.fresh())
	assert_eq(_snapshot().tool_upgrades, ToolUpgradeState.fresh())

func test_v20_and_v19_migrate_sequentially_without_mutating_input() -> void:
	var old: Dictionary = _snapshot()
	old.version = 20
	old.erase("tool_upgrades")
	var before: Dictionary = old.duplicate(true)
	var result: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(result.ok)
	assert_eq(int(result.snapshot.version), SaveSchema.VERSION)
	assert_eq(result.snapshot.tool_upgrades, ToolUpgradeState.fresh())
	assert_eq(result.snapshot.coins, old.coins)
	assert_eq(result.snapshot.inventory, old.inventory)
	assert_eq(result.snapshot.troughs, old.troughs)
	assert_eq(old, before)
	assert_true(adapter.restore(old, old.saved_at).ok)
	old.version = 19
	result = SaveSchema.validate(old, adapter.catalog)
	assert_true(result.ok)
	assert_eq(result.snapshot.land_starting_columns, 1)
	assert_eq(result.snapshot.tool_upgrades, ToolUpgradeState.fresh())
	assert_false(old.has("tool_upgrades"))

func test_levels_selected_ranges_and_coins_roundtrip_through_disk() -> void:
	_enable_harness()
	assert_true(world.tool_upgrades.purchase(&"hoe", 1, 30000).ok)
	assert_true(world.tool_upgrades.purchase(&"sowing", 1, 40000).ok)
	assert_true(world.tool_upgrades.purchase(&"watering_can", 1, 30000).ok)
	assert_true(world.tool_upgrades.purchase(&"watering_can", 2, 90000).ok)
	assert_true(world.tool_upgrade_state.select_size(&"hoe", 1))
	assert_true(world.tool_upgrade_state.select_size(&"watering_can", 2))
	var saved: Dictionary = _snapshot()
	var directory: String = "res://.godot/tool_upgrade_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(directory, adapter.catalog)
	assert_true(repository.write_profile("tool_upgrade_test", saved, 0).ok)
	world.tool_upgrade_state.restore(ToolUpgradeState.fresh())
	world.player.wallet.set_balance(0)
	var loaded: Dictionary = repository.read_profile("tool_upgrade_test")
	assert_true(loaded.ok)
	assert_true(adapter.restore(loaded.snapshot, saved.saved_at).ok)
	assert_eq(world.tool_upgrade_state.capture(), saved.tool_upgrades)
	assert_eq(world.player.wallet.balance, 310000)
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 1)
	assert_eq(world.tool_upgrade_state.selected_size(&"watering_can"), 2)
	DirAccess.remove_absolute(repository.path("tool_upgrade_test"))
	DirAccess.remove_absolute(directory)

func test_invalid_current_state_is_rejected_before_world_mutation() -> void:
	_enable_harness()
	world.tool_upgrades.purchase(&"hoe", 1, 30000)
	var saved: Dictionary = _snapshot()
	var original: Dictionary = saved.duplicate(true)
	saved.tool_upgrades.hoe.level = 7
	saved.coins = 123
	assert_false(adapter.restore(saved, saved.saved_at).ok)
	assert_eq(world.player.wallet.balance, original.coins)
	assert_eq(world.tool_upgrade_state.capture(), original.tool_upgrades)
	saved = original.duplicate(true)
	saved.erase("tool_upgrades")
	assert_false(SaveSchema.validate(saved, adapter.catalog).ok)
	saved = original.duplicate(true)
	saved.tool_upgrades.sowing.selected_size = 3
	assert_false(SaveSchema.validate(saved, adapter.catalog).ok)

func test_restore_during_purchase_is_rejected_before_mutation() -> void:
	_enable_harness()
	var saved: Dictionary = _snapshot()
	world.player.wallet.changed.connect(func(_balance: int) -> void:
		assert_false(adapter.restore(saved, saved.saved_at).ok)
		assert_eq(world.tool_upgrade_state.level(&"hoe"), 2))
	assert_true(world.tool_upgrades.purchase(&"hoe", 1, 30000).ok)
	assert_eq(world.player.wallet.balance, 470000)
	assert_eq(world.tool_upgrade_state.level(&"hoe"), 2)

func _start_save(service: GameSaveManager) -> void:
	_save_result = await service.save_game()

func test_load_failure_and_pending_save_disable_purchases() -> void:
	var repository: MemoryRepository = MemoryRepository.new()
	repository.snapshot = _snapshot()
	repository.snapshot.version = 20
	repository.snapshot.erase("tool_upgrades")
	var save: GameSaveManager = GameSaveManager.new()
	add_child_autofree(save)
	assert_true((await save.bind_world(world, repository, "tool_upgrade_test")).ok)
	assert_true(world.tool_upgrades.profile_ready)
	assert_true(world.tool_upgrades.purchasing_enabled)
	_enable_harness()
	assert_true(world.tool_upgrades.purchase(&"hoe", 1, 30000).ok)
	repository.hold_write = true
	_start_save(save)
	assert_true(save.busy)
	assert_false(world.tool_upgrades.profile_ready)
	assert_eq(world.tool_upgrades.quote(&"sowing").code, "unavailable")
	repository.release_write.emit()
	await wait_process_frames(2)
	assert_true(_save_result.ok)
	assert_true(world.tool_upgrades.profile_ready)
	assert_eq(repository.snapshot.tool_upgrades.hoe.level, 2)
	repository.fail_read = true
	assert_false((await save.load_game()).ok)
	assert_false(world.tool_upgrades.profile_ready)
	assert_eq(world.tool_upgrades.quote(&"sowing").code, "unavailable")
	assert_eq(world.tool_upgrade_state.level(&"hoe"), 2)

func test_six_by_six_roundtrip_preserves_selected_ranges() -> void:
	var saved: Dictionary = _snapshot()
	for key: String in saved.tool_upgrades:
		saved.tool_upgrades[key] = {"level": 6, "selected_size": 6}
	assert_true(adapter.restore(saved, saved.saved_at).ok)
	assert_eq(_snapshot().tool_upgrades, saved.tool_upgrades)
