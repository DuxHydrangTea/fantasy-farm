extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const FIXED: float = 1793155000.0
class MemoryRepository extends SaveRepository:
	var snapshot: Dictionary = {}
	func read_profile(_id: String) -> Dictionary:
		return {"ok": true, "found": not snapshot.is_empty(), "snapshot": snapshot.duplicate(true), "revision": int(snapshot.get("revision", 0))}
	func write_profile(_id: String, data: Dictionary, _expected: int) -> Dictionary:
		snapshot = data.duplicate(true)
		return {"ok": true, "revision": int(data.revision)}
var world: FarmWorld
var manager: GameSaveManager
var backend: MemoryRepository
var old_clock: Callable
var old_floor: float
var old_policy: bool
var old_processing: bool

func before_each() -> void:
	old_clock = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	old_processing = TimeManager.is_processing()
	old_policy = bool(ProjectSettings.get_setting("gameplay/offline_progress_enabled", false))
	ProjectSettings.set_setting("gameplay/offline_progress_enabled", false)
	TimeManager.use_wall_clock(FIXED)
	TimeManager.clock_source = func() -> float: return FIXED
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.land.state.restore_columns(12, 4)
	world.farming.restore_soil([{"cell": [48, 30], "state": 1}])
	world.farming.restore_crop(Vector2i(48, 30), SEED.crop as CropDefinition, FIXED - 10, FIXED + 50, 0.1, FIXED)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	backend = MemoryRepository.new()
	backend.snapshot = adapter.capture("offline_test", 1, FIXED)
	manager = GameSaveManager.new()
	add_child_autofree(manager)

func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	TimeManager.use_wall_clock(old_floor)
	TimeManager.clock_source = old_clock
	TimeManager.set_process(old_processing)
	ProjectSettings.set_setting("gameplay/offline_progress_enabled", old_policy)

func test_disabled_offline_resumes_exact_checkpoint_and_does_not_replay_workers() -> void:
	TimeManager.clock_source = func() -> float: return FIXED + 604800
	var result: Dictionary = await manager.bind_world(world, backend, "offline_test")
	assert_true(result.ok, str(result))
	assert_eq(TimeManager.now(), FIXED)
	assert_eq(world.workers.simulated_at, FIXED)
	assert_almost_eq(world.farming.get_crop(Vector2i(48, 30)).progress, float(backend.snapshot.crops[0].progress), 0.00001)
	assert_eq(world.player.wallet.balance, int(backend.snapshot.coins))
	assert_true((await manager.save_game()).ok)
	assert_true(backend.snapshot.has("wall_saved_at"))
	assert_eq(float(backend.snapshot.saved_at), FIXED)

func test_optional_offline_reenable_uses_only_time_since_last_real_save() -> void:
	ProjectSettings.set_setting("gameplay/offline_progress_enabled", true)
	backend.snapshot["wall_saved_at"] = Time.get_unix_time_from_system() - 10
	var result: Dictionary = await manager.bind_world(world, backend, "offline_test")
	assert_true(result.ok, str(result))
	assert_between(TimeManager.now() - FIXED, 9.0, 13.0, "Skipped days must not be granted retroactively")
	assert_lt(world.farming.get_crop(Vector2i(48, 30)).progress, 0.8)

func test_session_clock_preserves_online_progress_and_ignores_a_long_stall() -> void:
	var clock: FarmClock = FarmClock.new()
	clock.begin_session(1000)
	for index: int in range(10):
		clock._process(0.1)
	assert_almost_eq(clock.now(), 1001.0, 0.00001)
	clock._process(86400)
	assert_almost_eq(clock.now(), 1001.25, 0.00001)
	clock.begin_session(500)
	assert_eq(clock.now(), 500.0, "Switching to an older farm starts its own timeline")
	clock.free()
