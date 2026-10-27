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
				# Preserve the short maturity fixture used by offline-production tests.
				child.definition = child.definition.duplicate() as AnimalDefinition
				child.definition.maturity_seconds = 120.0
				child.get_node("NeedsComponent").time_manager = clock
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	(world as FarmWorld).land.state.restore_columns(48)
	selection = world.get_node("Player/ToolSelection") as ToolSelectionComponent
	catalog = SaveCatalog.new()
	for id: String in catalog.animals:
		catalog.animals[id] = catalog.animals[id].duplicate() as AnimalDefinition
		catalog.animals[id].maturity_seconds = 120.0
	adapter = WorldStateAdapter.new(world, catalog)

func _snapshot() -> Dictionary:
	return adapter.capture("test", 1, timestamp)

func test_wallet_restores_exact_balance_after_purchase_and_disk_roundtrip() -> void:
	var player: FarmPlayer = world.player
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var service: ShopService = ShopService.new(stock, player.wallet, selection.inventory)
	assert_true(service.buy(stock.offers[0], 3).ok)
	var saved: Dictionary = _snapshot()
	assert_eq(saved.coins, 970)
	var directory: String = "res://.godot/shop_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(directory, catalog)
	assert_true(repository.write_profile("test", saved, 0).ok)
	player.wallet.set_balance(0)
	var loaded: Dictionary = repository.read_profile("test")
	assert_true(loaded.ok)
	assert_true(adapter.restore(loaded.snapshot, timestamp).ok)
	assert_eq(player.wallet.balance, 970)
	assert_eq(selection.inventory.count_item(stock.offers[0].item.item_id), 3)
	DirAccess.remove_absolute(repository.path("test"))
	DirAccess.remove_absolute(directory)

func test_bought_animals_age_and_wallet_roundtrip_and_sold_animals_stay_sold() -> void:
	# Trade lifecycle uses production defaults rather than the short-maturity save fixture.
	adapter.catalog = SaveCatalog.new()
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var trades: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, clock)
	var result: Dictionary = trades.buy(stock.animal_offers[0], 1)
	assert_true(result.ok)
	var actor: AnimalActor = result.animals[0]
	var id: String = String(actor.persistent_id)
	var saved: Dictionary = _snapshot()
	timestamp += 60.0
	assert_true(adapter.restore(saved, timestamp).ok)
	actor = _actor(id)
	assert_not_null(actor)
	assert_eq(actor.growth.age_seconds, 60.0)
	assert_false(actor.growth.is_adult())
	assert_eq(world.player.wallet.balance, 840)
	assert_true(trades.sell(actor).ok)
	assert_eq(world.player.wallet.balance, 920)
	var sold: Dictionary = _snapshot()
	assert_eq(sold.animals.size(), 36)
	await wait_physics_frames(2)
	assert_true(adapter.restore(sold, timestamp).ok)
	assert_null(_actor(id))
	assert_eq(world.player.wallet.balance, 920)

func test_saving_mid_attraction_keeps_ground_quantity_and_position_until_arrival() -> void:
	var player: FarmPlayer = world.player
	player.position = Vector2(1500, 900)
	var pickup: ItemPickup = preload("res://scenes/objects/item_pickup.tscn").instantiate() as ItemPickup
	pickup.item = load("res://items/animal_produces/chicken_egg.tres") as ItemDefinition
	pickup.amount = 5
	pickup.persistent_id = &"flight_test"
	pickup.position = player.position + Vector2(40, 0)
	world.add_child(pickup)
	var collector: ItemCollector = player.get_node("ItemCollector") as ItemCollector
	var before: int = selection.inventory.count_item(pickup.item.item_id)
	assert_true(pickup.attract_to(collector))
	pickup._physics_process(0.03)
	assert_lt(pickup.sprite.position.x, 0.0)
	var snapshot: Dictionary = _snapshot()
	var found: bool = false
	for record: Dictionary in snapshot.pickups:
		if record.id == "flight_test":
			found = true
			assert_eq(record.amount, 5)
			assert_eq(record.position, [1540.0, 900.0])
	assert_true(found)
	assert_eq(selection.inventory.count_item(pickup.item.item_id), before)
	assert_true(adapter.restore(snapshot, timestamp).ok)
	assert_eq(selection.inventory.count_item(&"chicken_egg"), before)
	for child: Node in world.get_children():
		if child is ItemPickup and child.persistent_id == &"flight_test":
			assert_false(child.is_attracting())
			assert_eq(child.amount, 5)
			assert_eq(child.position, Vector2(1540, 900))
			return
	fail_test("Restored ground pile must still exist")

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

func test_capture_sync_excludes_animals_that_die_before_the_same_frame_save() -> void:
	var id: String = String((world.get_node("BarnPen/Cow_1") as AnimalActor).persistent_id)
	timestamp += 14.0 * 86400.0
	var saved: Dictionary = _snapshot()
	assert_eq(saved.animals.size(), 0, "Capture must exclude actors retired by its own clock sync")
	assert_false(saved.animal_pens.is_empty())
	assert_true(SaveSchema.validate(saved, catalog).ok)
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(_snapshot().animals.size(), 0, "Initialized pens cannot respawn their default animals")
	await wait_physics_frames(2)
	assert_null(_actor(id))

func test_offline_death_preserves_final_output_and_stays_dead_after_repeated_reload() -> void:
	var cow: AnimalActor = world.get_node("BarnPen/Cow_1") as AnimalActor
	var id: String = String(cow.persistent_id)
	cow.growth.configure(cow.definition.maturity_seconds, cow.definition.lifespan_seconds - 10.0, cow.definition.lifespan_seconds)
	cow.production.restore_state(55.0, 2)
	var saved: Dictionary = _snapshot()
	timestamp += 20.0
	assert_true(adapter.restore(saved, timestamp).ok)
	cow = _actor(id)
	assert_true(cow.is_dead())
	assert_eq(cow.product_pickup().amount, 3, "Only ten seconds before death may complete one last batch")
	var next: Dictionary = _snapshot()
	assert_eq(next.animals.size(), 35)
	var cow_piles: int = 0
	for row: Dictionary in next.pickups:
		if row.item == "cow_milk":
			cow_piles += int(row.amount)
	assert_eq(cow_piles, 3)
	await wait_physics_frames(2)
	assert_null(_actor(id))
	assert_true(adapter.restore(next, timestamp).ok)
	assert_true(adapter.restore(next, timestamp).ok)
	assert_null(_actor(id))
	assert_eq(_snapshot().animals.size(), 35)
	cow_piles = 0
	for row: Dictionary in _snapshot().pickups:
		if row.item == "cow_milk":
			cow_piles += int(row.amount)
	assert_eq(cow_piles, 3)

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
	assert_eq(saved.version, SaveSchema.VERSION)
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
	saved.flower_gardens[0].flowers = [{"cell": [18, 0], "flower": "flower_01", "planted_at": 1000, "growth_started_at": -1, "matures_at": 0, "progress": 0}]
	var position: Vector2 = world.get_node("Player").position
	saved.player.position = [1, 1]
	assert_false(adapter.restore(saved, timestamp).ok)
	assert_eq(world.get_node("Player").position, position)

func test_version_two_garden_migration_preserves_flowers_in_reduced_layout() -> void:
	var saved: Dictionary = _snapshot()
	saved.version = 2
	var template: Dictionary = {"cell": [0, 0], "flower": "flower_01", "planted_at": timestamp - 100.0, "growth_started_at": timestamp - 100.0, "matures_at": timestamp + 100.0, "progress": 0.5}
	saved.flower_gardens[0].flowers = []
	var legacy_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 2), Vector2i(5, 3), Vector2i(9, 5)]
	for cell: Vector2i in legacy_cells:
		var flower: Dictionary = template.duplicate(true)
		flower.cell = [cell.x, cell.y]
		saved.flower_gardens[0].flowers.append(flower)
	var original: String = JSON.stringify(saved)
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(JSON.stringify(saved), original, "Migration must not alter the source snapshot")
	var garden: Node = world.get_node("FlowerGarden")
	assert_eq(garden.pots.size(), 80)
	var restored: int = 0
	for current: Node in garden.pots.values():
		if current.definition == null:
			continue
		restored += 1
		assert_eq(String(current.definition.flower_id), template.flower)
		assert_eq(current.capture(timestamp).growth_started_at, template.growth_started_at)
		assert_eq(current.capture(timestamp).progress, template.progress)
	assert_eq(restored, 4)
	assert_eq(_snapshot().flower_gardens[0].flowers.size(), 4)
	assert_true(adapter.restore(_snapshot(), timestamp).ok, "Version 3 load cannot remap a second time")

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
	var ready: Node = garden.pots[Vector2i(12, 0)]
	assert_true(ready.harvest(selection.inventory))
	var after: Dictionary = _snapshot()
	assert_true(after.flower_gardens[0].starter_flowers_added)
	assert_true(adapter.restore(after, timestamp).ok)
	assert_null(ready.definition, "A harvested starter must remain empty after loading")

func test_produce_sale_wallet_inventory_and_open_menu_roundtrip() -> void:
	var carrot: ItemDefinition = load("res://items/harvest_produces/carrot_produces.tres") as ItemDefinition
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	selection.inventory.add(carrot, 120)
	var sale: ProduceSaleService = ProduceSaleService.new(prices, world.player.wallet, selection.inventory)
	assert_true(sale.sell(prices.find(carrot.item_id), 105).ok)
	assert_eq(world.player.wallet.balance, 1525)
	var saved: Dictionary = _snapshot()
	var directory: String = "res://.godot/produce_sale_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(directory, catalog)
	assert_true(repository.write_profile("test", saved, 0).ok)
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	world.player.position = buyer.interaction_position() + Vector2(0, 24)
	assert_true(buyer.open_shop(world.player))
	world.player.wallet.set_balance(0)
	selection.inventory.remove(carrot.item_id, 15)
	var loaded: Dictionary = repository.read_profile("test")
	assert_true(loaded.ok)
	assert_true(adapter.restore(loaded.snapshot, timestamp).ok)
	assert_false(buyer.menu.is_open)
	assert_false(selection.shop_open)
	assert_eq(world.player.wallet.balance, 1525)
	assert_eq(selection.inventory.count_item(carrot.item_id), 15)
	DirAccess.remove_absolute(repository.path("test"))
	DirAccess.remove_absolute(directory)

func test_retained_feed_survives_disk_roundtrip_and_invalid_reserve_is_atomic() -> void:
	var trough: AnimalTrough = world.get_node("CoopPen/FeedTrough") as AnimalTrough
	trough.feed_reserve = 123
	var saved: Dictionary = _snapshot()
	var directory: String = "res://.godot/feed_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(directory, catalog)
	assert_true(repository.write_profile("test", saved, 0).ok)
	trough.feed_reserve = 0
	var loaded: Dictionary = repository.read_profile("test")
	assert_true(loaded.ok)
	assert_true(adapter.restore(loaded.snapshot, timestamp).ok)
	assert_eq(trough.feed_reserve,123)
	var broken: Dictionary = _snapshot()
	for row: Dictionary in broken.troughs:
		if row.id == String(trough.persistent_id):
			row.feed_reserve = trough.feed_item.food_units_per_item
	broken.coins = 12
	var coins: int = world.player.wallet.balance
	assert_false(adapter.restore(broken,timestamp).ok)
	assert_eq(world.player.wallet.balance,coins)
	assert_eq(trough.feed_reserve,123)
	DirAccess.remove_absolute(repository.path("test"))
	DirAccess.remove_absolute(directory)

func test_v7_trough_migration_starts_with_no_retained_feed_without_mutating_input() -> void:
	var old: Dictionary = _snapshot()
	old.version = 7
	for row: Dictionary in old.troughs:
		row.erase("feed_reserve")
	var checked: Dictionary = SaveSchema.validate(old,catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.version,SaveSchema.VERSION)
	for row: Dictionary in checked.snapshot.troughs:
		assert_eq(row.feed_reserve,0)
	for row: Dictionary in old.troughs:
		assert_false(row.has("feed_reserve"))
