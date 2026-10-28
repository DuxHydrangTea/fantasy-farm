extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const IDS: Dictionary = {
	"CoopPen/FeedTrough": "placed_2042315591", "CoopPen/FeedTrough2": "placed_144181841",
	"CoopPen/WaterTrough": "placed_2041273187", "CoopPen/WaterTrough2": "placed_1891560272",
	"BarnPen/FeedTrough": "placed_1563140842", "BarnPen/WaterTrough": "placed_203535476",
	"BarnPen/FeedTrough2": "barn_feedtrough_02", "BarnPen/WaterTrough2": "barn_watertrough_02",
	"PondPen/FeedTrough": "pond_feedtrough", "PondPen/WaterTrough": "pond_watertrough",
	"PondPen/FeedTrough2": "pond_feedtrough_02", "PondPen/WaterTrough2": "pond_watertrough_02"
}

class MemoryRepository extends SaveRepository:
	var snapshot: Dictionary
	func read_profile(_profile: String) -> Dictionary:
		return {"ok": true, "found": true, "snapshot": snapshot.duplicate(true), "revision": snapshot.revision, "recovered": false}
	func write_profile(_profile: String, data: Dictionary, _expected: int) -> Dictionary:
		snapshot = data.duplicate(true)
		return {"ok": true, "revision": data.revision}

var world: FarmWorld
var adapter: WorldStateAdapter

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world) # A child world never binds the personal SaveManager.
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())

func _legacy_snapshot() -> Dictionary:
	var data: Dictionary = adapter.capture("compatibility_test", 1, world.farming.time_manager.now())
	for row: Dictionary in data.troughs:
		row.stock = 120 if String(row.pen).begins_with("placed_d2d638") else 600
		row.consumed_fraction = 0.0
		row.feed_reserve = 0
	return data

func test_authored_troughs_keep_persistent_ids_and_economy_capacity() -> void:
	var ids: Dictionary = {}
	for path: String in IDS:
		var trough: AnimalTrough = world.get_node(path)
		assert_eq(String(trough.persistent_id), IDS[path])
		assert_false(ids.has(IDS[path]))
		ids[IDS[path]] = true
		assert_eq(trough.capacity, 1200)
	assert_eq(adapter.capture("compatibility_test", 1, world.farming.time_manager.now()).troughs.size(), 12)

func test_previous_600_stock_save_restores_without_clamping_or_rewriting_input() -> void:
	var saved: Dictionary = _legacy_snapshot()
	var original: Dictionary = saved.duplicate(true)
	assert_true(adapter.preflight(saved).ok)
	assert_true(adapter.restore(saved, saved.saved_at).ok)
	assert_eq(saved, original)
	for path: String in IDS:
		var trough: AnimalTrough = world.get_node(path)
		assert_eq(trough.stock, 120 if path.begins_with("CoopPen/") else 600)

func test_restore_uses_scene_positions_and_preserves_saved_stock() -> void:
	var saved: Dictionary = _legacy_snapshot()
	var authored: Dictionary = {}
	for path: String in IDS:
		var trough: AnimalTrough = world.get_node(path)
		authored[IDS[path]] = trough.position
	for row: Dictionary in saved.troughs:
		row.position = [999.0, 999.0] # An old layout, not the authored location.
	assert_true(adapter.restore(saved, saved.saved_at).ok)
	for path: String in IDS:
		var trough: AnimalTrough = world.get_node(path)
		assert_eq(trough.position, authored[IDS[path]])
		assert_eq(trough.stock, 120 if path.begins_with("CoopPen/") else 600)
	var captured: Dictionary = adapter.capture("compatibility_test", 2, saved.saved_at)
	for row: Dictionary in captured.troughs:
		var expected: Vector2 = authored[row.id]
		assert_eq(row.position, [expected.x, expected.y])

func test_real_capacity_mismatch_is_still_rejected_before_restore() -> void:
	var saved: Dictionary = _legacy_snapshot()
	var trough: AnimalTrough = world.get_node("BarnPen/FeedTrough")
	trough.capacity = 120 # Reproduce the editor regression from the reported error.
	var coins: int = world.player.wallet.balance
	assert_false(adapter.restore(saved, saved.saved_at).ok)
	assert_eq(world.player.wallet.balance, coins)
	assert_false(adapter.preflight(saved).ok)

func test_missing_persistent_id_is_still_rejected() -> void:
	var saved: Dictionary = _legacy_snapshot()
	world.get_node("BarnPen/FeedTrough2").persistent_id = &"unrecognized_trough"
	assert_false(adapter.preflight(saved).ok)

func test_loading_legacy_stock_reenables_saving_and_roundtrips() -> void:
	var backend: MemoryRepository = MemoryRepository.new()
	backend.snapshot = _legacy_snapshot()
	var service: GameSaveManager = GameSaveManager.new()
	add_child_autofree(service)
	var result: Dictionary = await service.bind_world(world, backend, "compatibility_test")
	assert_true(result.ok)
	assert_true(service.writes_enabled)
	assert_true((await service.save_game()).ok)
	assert_eq(backend.snapshot.troughs.size(), 12)
	for row: Dictionary in backend.snapshot.troughs:
		assert_eq(row.stock, 120 if String(row.pen).begins_with("placed_d2d638") else 600)
