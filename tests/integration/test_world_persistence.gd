extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
class MemoryRepository extends SaveRepository:
	signal release_write
	var record: Dictionary = {}
	var hold_write: bool = false
	var fail_read: bool = false
	var fail_write: bool = false
	func read_profile(_profile: String) -> Dictionary:
		if fail_read:
			return {"ok": false, "code": "corrupt", "error": "Test corruption"}
		return {"ok": true, "found": not record.is_empty(), "snapshot": record.duplicate(true)}
	func write_profile(_profile: String, snapshot: Dictionary, expected: int) -> Dictionary:
		if hold_write:
			await release_write
		if fail_write:
			return {"ok": false, "code": "io", "error": "Test IO failure"}
		if int(record.get("revision", 0)) != expected:
			return {"ok": false, "code": "conflict", "error": "Test revision conflict"}
		record = snapshot.duplicate(true)
		return {"ok": true, "revision": int(snapshot.revision)}

class ServiceHarness extends GameSaveManager:
	var test_clock: FarmClock
	func _clock() -> FarmClock:
		return test_clock
var world: Node2D
var adapter: WorldStateAdapter
var clock: FarmClock
var timestamp: float = 1000.0
var catalog: SaveCatalog
var farm: FarmingController
var selection: ToolSelectionComponent

func before_each() -> void:
	timestamp = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	world = WORLD.instantiate() as Node2D
	# Core save fixtures keep their original two pens; pond migration has its own test.
	world.get_node("PondPen").free()
	# No scatter generation or physics movement in persistence fixtures.
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	farm = world.get_node("FarmingController") as FarmingController
	farm.time_manager = clock
	world.get_node("FlowerGarden").time_manager = clock
	for pen_name: String in ["CoopPen", "BarnPen"]:
		for child: Node in world.get_node(pen_name).get_children():
			if child is AnimalActor:
				child.get_node("NeedsComponent").time_manager = clock
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	selection = world.get_node("Player/ToolSelection") as ToolSelectionComponent
	catalog = SaveCatalog.new()
	adapter = WorldStateAdapter.new(world, catalog)

func _snapshot() -> Dictionary:
	return adapter.capture("test", 1, timestamp)

func _actor(id: String) -> AnimalActor:
	for pen_name: String in ["CoopPen", "BarnPen"]:
		for node: Node in world.get_node(pen_name).get_children():
			if node is AnimalActor and String(node.persistent_id) == id:
				return node as AnimalActor
	return null

func test_player_inventory_soil_and_crop_roundtrip_through_file() -> void:
	world.get_node("Player").position = Vector2(400, 300)
	selection.select_slot(2)
	selection.inventory.remove(&"carrot_seed", 3)
	var cell: Vector2i = Vector2i(20, 20)
	farm.restore_soil([{"cell": [20, 20], "state": FarmingController.Soil.WET}, {"cell": [21, 20], "state": FarmingController.Soil.DRY}])
	farm.restore_crop(cell, catalog.crops["carrot"], 1000.0, 1010.0, 0.0, 1000.0)
	var folder: String = "res://.godot/save_tests/roundtrip_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repo: LocalSaveRepository = LocalSaveRepository.new(folder, catalog)
	var saved: Dictionary = _snapshot()
	assert_true(repo.write_profile("test", saved, 0).ok)
	selection.inventory.remove(&"carrot_seed", 100)
	world.get_node("Player").position = Vector2.ZERO
	selection.select_slot(0)
	farm.restore_soil([])
	var read: Dictionary = repo.read_profile("test")
	assert_true(read.ok)
	assert_true(adapter.restore(read.snapshot, 1006.0).ok)
	assert_eq(world.get_node("Player").position, Vector2(400, 300))
	assert_eq(selection.selected_index, 2)
	assert_eq(selection.inventory.count_item(&"carrot_seed"), 9)
	assert_eq(farm.get_soil_state(cell), FarmingController.Soil.WET)
	assert_eq(farm.get_soil_state(Vector2i(21, 20)), FarmingController.Soil.DRY)
	assert_almost_eq(farm.get_crop(cell).progress, 0.6, 0.0001)
	assert_eq(farm.get_crop(cell).stage, 1)
	DirAccess.remove_absolute(repo.path("test"))
	DirAccess.remove_absolute(folder)

func test_offline_production_stacks_into_same_saved_pile_once() -> void:
	timestamp = 1060.0
	clock.refresh()
	var cow: AnimalActor = world.get_node("BarnPen/Cow_1") as AnimalActor
	var saved: Dictionary = _snapshot()
	var id: String = String(cow.persistent_id)
	var pile_id: String = String(cow.product_pickup().persistent_id)
	assert_true(adapter.restore(saved, 1180.0).ok)
	cow = _actor(id)
	assert_not_null(cow)
	assert_eq(cow.product_pickup().amount, 3)
	assert_eq(String(cow.product_pickup().persistent_id), pile_id)
	assert_almost_eq(cow.growth.age_seconds, 300.0, 0.0001)
	assert_almost_eq(cow.needs.satiety, 70.0, 0.001)
	cow.needs.update_at(1180.0)
	assert_eq(cow.product_pickup().amount, 3, "Same timestamp cannot duplicate offline batches")
	assert_eq(adapter.capture("test", 2, 1180.0).animals.size(), 36)

func test_long_offline_interval_stops_production_when_needs_run_out() -> void:
	var cow: AnimalActor = world.get_node("BarnPen/Cow_1") as AnimalActor
	var saved: Dictionary = _snapshot()
	var id: String = String(cow.persistent_id)
	assert_true(adapter.restore(saved, 100000.0).ok)
	cow = _actor(id)
	assert_eq(cow.needs.satiety, 0.0)
	assert_eq(cow.needs.hydration, 0.0)
	assert_eq(cow.product_pickup().amount, 10)
	assert_almost_eq(cow.growth.age_seconds, 99120.0, 0.001)

func test_collected_default_pickup_and_removed_animal_do_not_respawn() -> void:
	var default_feed: ItemPickup = world.get_node("BarnPen/LivestockFeed") as ItemPickup
	default_feed.free()
	var cow: AnimalActor = world.get_node("BarnPen/Cow_1") as AnimalActor
	cow.free()
	var saved: Dictionary = _snapshot()
	assert_true(adapter.restore(saved, timestamp).ok)
	var next: Dictionary = _snapshot()
	assert_eq(next.animals.size(), 35)
	assert_eq(next.pickups.size(), 10, "Only the ten flower seed supplies remain")

func test_trough_stock_and_entity_ids_survive_renaming() -> void:
	var trough: Node = world.get_node("CoopPen/FeedTrough")
	trough.stock = 7
	var saved: Dictionary = _snapshot()
	trough.stock = 100
	trough.name = "RenamedTrough"
	world.get_node("CoopPen").name = "RenamedPen"
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(int(trough.stock), 7)

func test_invalid_load_does_not_mutate_world() -> void:
	var saved: Dictionary = _snapshot()
	var position: Vector2 = world.get_node("Player").position
	saved.player.position = [1, 1]
	saved.animals[0].animal = "unknown_animal"
	assert_false(adapter.restore(saved, timestamp).ok)
	assert_eq(world.get_node("Player").position, position)
	assert_eq(_snapshot().animals.size(), 36)

func test_progress_does_not_go_back_when_system_clock_moves_back() -> void:
	var cow: AnimalActor = world.get_node("BarnPen/Cow_1") as AnimalActor
	timestamp = 1030.0
	clock.refresh()
	var id: String = String(cow.persistent_id)
	var saved: Dictionary = _snapshot()
	assert_true(adapter.restore(saved, 900.0).ok)
	cow = _actor(id)
	assert_almost_eq(cow.production.progress_seconds, 30.0, 0.001)
	assert_almost_eq(cow.growth.age_seconds, 150.0, 0.001)

func test_test_world_does_not_bind_real_profile() -> void:
	await get_tree().process_frame
	assert_null(get_node("/root/SaveManager").adapter)

func test_inventory_replace_is_atomic_and_emits_once() -> void:
	var bag: InventoryComponent = selection.inventory
	watch_signals(bag)
	var stacks: Array[Dictionary] = []
	for index: int in range(bag.slot_count):
		stacks.append({"item": null, "count": 0})
	stacks[0] = {"item": catalog.items["hoe"], "count": 2}
	assert_false(bag.replace_slots(stacks))
	assert_eq(bag.count_item(&"hoe"), 1)
	assert_signal_not_emitted(bag, "changed")
	stacks[0].count = 1
	assert_true(bag.replace_slots(stacks))
	assert_signal_emit_count(bag, "changed", 1)

func _service(repo: MemoryRepository) -> ServiceHarness:
	var service: ServiceHarness = ServiceHarness.new()
	service.test_clock = clock
	add_child_autofree(service)
	service.set_process(false)
	await service.bind_world(world, repo, "test")
	return service

func test_service_supports_async_backend_and_blocks_overlapping_operations() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	var service: ServiceHarness = await _service(repo)
	repo.hold_write = true
	service.save_game()
	assert_true(service.busy)
	assert_false((await service.load_game()).ok)
	assert_false((await service.save_game()).ok)
	repo.release_write.emit()
	await get_tree().process_frame
	assert_false(service.busy)
	assert_eq(service.revision, 1)
	assert_eq(int(repo.record.revision), 1)
	assert_true(service.writes_enabled)

func test_service_autosaves_and_loads_through_injected_repository() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	var service: ServiceHarness = await _service(repo)
	world.get_node("Player").position = Vector2(500, 400)
	service._process(31.0)
	assert_eq(service.revision, 1)
	world.get_node("Player").position = Vector2.ZERO
	assert_true((await service.load_game()).ok)
	assert_eq(world.get_node("Player").position, Vector2(500, 400))
	assert_true((await service.save_game()).ok)
	assert_eq(service.revision, 2)

func test_failed_read_disables_autosave_and_keeps_live_world_intact() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	repo.fail_read = true
	var position: Vector2 = world.get_node("Player").position
	var service: ServiceHarness = await _service(repo)
	assert_false(service.writes_enabled)
	assert_false((await service.save_game()).ok)
	service._process(31.0)
	assert_true(repo.record.is_empty())
	assert_eq(world.get_node("Player").position, position)

func test_failed_write_keeps_revision_and_can_be_retried() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	var service: ServiceHarness = await _service(repo)
	repo.fail_write = true
	assert_false((await service.save_game()).ok)
	assert_eq(service.revision, 0)
	assert_true(service.writes_enabled)
	repo.fail_write = false
	assert_true((await service.save_game()).ok)
	assert_eq(service.revision, 1)

func test_remote_invalid_snapshot_is_rejected_before_mutation() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	repo.record = _snapshot()
	repo.record.inventory[0].count = 99999
	var position: Vector2 = world.get_node("Player").position
	var service: ServiceHarness = await _service(repo)
	assert_false(service.writes_enabled)
	assert_eq(world.get_node("Player").position, position)

func test_binding_existing_profile_restores_it_automatically() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	repo.record = _snapshot()
	var saved_position: Vector2 = world.get_node("Player").position
	world.get_node("Player").position = Vector2(1, 1)
	var service: ServiceHarness = await _service(repo)
	assert_eq(service.revision, 1)
	assert_true(service.writes_enabled)
	assert_eq(world.get_node("Player").position, saved_position)

func test_revision_conflict_disables_writes_until_successful_reload() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	var service: ServiceHarness = await _service(repo)
	repo.record = _snapshot()
	assert_false((await service.save_game()).ok)
	assert_false(service.writes_enabled)
	assert_eq(service.revision, 0)
	assert_true((await service.load_game()).ok)
	assert_true(service.writes_enabled)
	assert_eq(service.revision, 1)
	assert_true((await service.save_game()).ok)
	assert_eq(service.revision, 2)

func test_quit_write_failure_leaves_game_running_for_retry() -> void:
	var repo: MemoryRepository = MemoryRepository.new()
	var service: ServiceHarness = await _service(repo)
	repo.fail_write = true
	await service._quit_with_save()
	assert_true(service._quit_failed)
	assert_false(service._closing)
	assert_eq(service.revision, 0)
	repo.fail_write = false
	assert_true((await service.save_game()).ok)
	assert_false(service._quit_failed)

func test_flower_state_roundtrip_and_offline_growth_without_duplicate_supplies() -> void:
	var garden: Node = world.get_node("FlowerGarden")
	var pot: Node = garden.pots[Vector2i.ZERO]
	selection.inventory.add(catalog.items["flower_01_seed"], 2)
	var slot: int = -1
	for index: int in range(selection.inventory.slot_count):
		if selection.inventory.slot(index).item == catalog.items["flower_01_seed"]:
			slot = index
	assert_true(pot.plant(selection.inventory, slot, timestamp))
	assert_true(pot.water(timestamp))
	var saved: Dictionary = _snapshot()
	assert_eq(saved.version, 2)
	assert_eq(saved.flower_gardens.size(), 1)
	assert_true(adapter.restore(saved, 1060.0).ok)
	assert_almost_eq(pot.progress, 0.5, 0.001)
	assert_eq(pot.stage, 2)
	var supplies: int = 0
	for pile: Dictionary in _snapshot().pickups:
		if String(pile.id).begins_with("flower_seed_supply_"):
			supplies += 1
	assert_eq(supplies, 10, "Offline animal output must not duplicate flower supplies")
	assert_true(adapter.restore(saved, 1120.0).ok)
	assert_true(pot.is_mature())

func test_version_one_migration_keeps_progress_and_initializes_new_garden() -> void:
	var saved: Dictionary = _snapshot()
	saved.version = 1
	saved.erase("flower_gardens")
	var old_piles: Array = []
	for row: Dictionary in saved.pickups:
		if not String(row.id).begins_with("flower_seed_supply_"):
			old_piles.append(row)
	saved.pickups = old_piles
	var count: int = selection.inventory.count_item(&"carrot_seed")
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(selection.inventory.count_item(&"carrot_seed"), count)
	assert_eq(_snapshot().animals.size(), 36)
	assert_eq(_snapshot().pickups.size(), old_piles.size() + 10)
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(_snapshot().pickups.size(), old_piles.size() + 10, "Repeated legacy loads cannot duplicate seed supplies")

func test_invalid_flower_cell_rejects_whole_load_before_mutation() -> void:
	var saved: Dictionary = _snapshot()
	saved.flower_gardens[0].flowers = [{"cell": [10, 0], "flower": "flower_01", "planted_at": 1000, "growth_started_at": -1, "matures_at": 0, "progress": 0}]
	var position: Vector2 = world.get_node("Player").position
	saved.player.position = [1, 1]
	assert_false(adapter.restore(saved, timestamp).ok)
	assert_eq(world.get_node("Player").position, position)

func test_collected_flower_seed_supply_stays_collected_after_reload() -> void:
	world.get_node("FlowerGarden/FlowerSeedSupply_01").free()
	var saved: Dictionary = _snapshot()
	assert_true(adapter.restore(saved, timestamp).ok)
	var supplies: int = 0
	for pile: Dictionary in _snapshot().pickups:
		assert_ne(pile.id, "flower_seed_supply_01")
		if String(pile.id).begins_with("flower_seed_supply_"):
			supplies += 1
	assert_eq(supplies, 9)

func test_starting_flowers_upgrade_existing_save_without_overwriting_or_respawning() -> void:
	var saved: Dictionary = _snapshot()
	saved.flower_gardens[0].erase("starter_flowers_added")
	saved.flower_gardens[0].flowers = []
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(_snapshot().flower_gardens[0].flowers.size(), 8)
	var garden: Node = world.get_node("FlowerGarden")
	var ready: Node = garden.pots[Vector2i(8, 0)]
	assert_true(ready.harvest(selection.inventory))
	var after: Dictionary = _snapshot()
	assert_true(after.flower_gardens[0].starter_flowers_added)
	assert_true(adapter.restore(after, timestamp).ok)
	assert_null(ready.definition, "A harvested starter must remain empty after loading")
