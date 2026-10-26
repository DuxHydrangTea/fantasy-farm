extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const COOP: StringName = &"placed_d2d638f2f4f64f5ca773aba052d29f5a"
const BARN: StringName = &"placed_bcb6d434c48b4f9fbac1620421e64390"
const POND: StringName = &"waterfowl_pen_01"
class RejectState:
	extends PenUpgradeState
	func commit(_id: StringName, _expected: int) -> bool:
		return false

class MemoryRepository:
	extends SaveRepository
	var snapshot: Dictionary = {}
	var writes: int = 0
	var fail_writes: bool = false
	func read_profile(_profile: String) -> Dictionary:
		if snapshot.is_empty():
			return {"ok":true, "found":false, "revision":0}
		return {"ok":true, "found":true, "snapshot":snapshot.duplicate(true), "revision":snapshot.revision}
	func write_profile(_profile: String, data: Dictionary, _expected: int) -> Dictionary:
		if fail_writes:
			return SaveSchema.failure("Test write failed.", "io")
		snapshot = data.duplicate(true)
		writes += 1
		return {"ok":true, "revision":data.revision}

var world: FarmWorld
var service: PenUpgradeService

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	service = world.pen_upgrades
	service.profile_ready = true
	world.player.wallet.set_balance(100000000)

func pen(id: StringName) -> AnimalPen:
	for node: Node in world.get_children():
		if node is AnimalPen and (node as AnimalPen).persistent_id == id:
			return node as AnimalPen
	return null

func test_prices_and_all_five_levels_are_independent() -> void:
	assert_true(service.catalog.valid())
	for id: StringName in [COOP, BARN, POND]:
		assert_eq(pen(id).capacity, 5)
		for level: int in range(1, 6):
			var quote: Dictionary = service.quote(pen(id))
			var balance: int = world.player.wallet.balance
			assert_true(quote.ok)
			assert_true(service.purchase(pen(id), level, int(quote.price)).ok)
			assert_eq(pen(id).capacity, (level + 1) * 5)
			assert_eq(world.player.wallet.balance, balance - int(quote.price))
		assert_eq(service.quote(pen(id)).code, "max_level")
	var costs: Dictionary = service.catalog.prices
	assert_eq(costs.coop, [20000, 40000, 80000, 140000, 220000])
	assert_eq(costs.pond, [30000, 60000, 120000, 210000, 330000])
	assert_eq(costs.barn, [60000, 120000, 240000, 420000, 660000])

func test_failed_stale_reentrant_and_rollback_purchases_do_not_double_spend() -> void:
	var coop: AnimalPen = pen(COOP)
	world.player.wallet.set_balance(19999)
	assert_eq(service.purchase(coop, 1, 20000).code, "insufficient_coins")
	assert_eq(coop.capacity, 5)
	world.player.wallet.set_balance(100000)
	assert_eq(service.purchase(coop, 1, 1).code, "stale_offer")
	assert_eq(world.player.wallet.balance, 100000)
	var nested: Array[String] = []
	var callback: Callable = func(_balance: int) -> void:
		nested.append(str(service.purchase(coop, 2, 40000).code))
		assert_eq(coop.capacity, 10)
		assert_eq(service.state.level(COOP), 2)
	world.player.wallet.changed.connect(callback)
	assert_true(service.purchase(coop, 1, 20000).ok)
	world.player.wallet.changed.disconnect(callback)
	assert_eq(nested, ["busy"])
	assert_eq(world.player.wallet.balance, 80000)
	assert_eq(service.purchase(coop, 1, 20000).code, "stale_offer")
	assert_eq(pen(BARN).capacity, 5)
	assert_eq(pen(POND).capacity, 5)
	service.state = RejectState.new()
	coop.capacity = 5
	assert_false(service.purchase(coop, 1, 20000).ok)
	assert_eq(world.player.wallet.balance, 80000)
	assert_eq(coop.capacity, 5)

func test_legacy_population_migration_and_invalid_progress() -> void:
	for count: int in [0, 5, 6, 29, 30, 31, 36]:
		var animals: Array = []
		for index: int in range(count):
			animals.append({"pen":String(COOP)})
		var levels: Dictionary = PenUpgradeState.migrate(animals)
		assert_true(PenUpgradeState.valid(levels))
		assert_eq(int(levels[String(COOP)]), clampi(ceili(float(count) / 5), 1, 6))
		assert_eq(int(levels[String(BARN)]), 1)
	assert_false(PenUpgradeState.valid({}))
	for value: Variant in [0, 7, 1.5, "2", null]:
		var levels: Dictionary = PenUpgradeState.fresh()
		levels[String(COOP)] = value
		assert_false(PenUpgradeState.valid(levels))

func test_capture_reload_keeps_paid_capacity_even_after_animals_are_removed() -> void:
	assert_true(service.purchase(pen(COOP), 1, 20000).ok)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("pen_test", 1, world.farming.time_manager.now())
	assert_eq(int(snapshot.pen_upgrades[String(COOP)]), 2)
	assert_true(SaveSchema.validate(snapshot, adapter.catalog).ok)
	assert_true(adapter.restore(snapshot, float(snapshot.saved_at)).ok)
	assert_eq(pen(COOP).capacity, 10)
	assert_eq(pen(BARN).capacity, 5)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 33
	legacy.erase("pen_upgrades")
	var migrated: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(migrated.ok)
	assert_false(legacy.has("pen_upgrades"))
	assert_eq(int(migrated.snapshot.version), SaveSchema.VERSION)

func test_buying_animals_obeys_paid_capacity_and_distinguishes_physical_space() -> void:
	await wait_physics_frames(3)
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var trading: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, world.farming.time_manager)
	var chicken: AnimalShopOffer = stock.animal_offers[0]
	assert_eq(chicken.animal.species, AnimalTypes.Species.CHICKEN)
	var bought: Dictionary = trading.buy(chicken, 5)
	assert_true(bought.ok, str(bought))
	assert_eq(PenStatus.members(pen(COOP)).size(), 5)
	assert_eq(trading.quote_buy(chicken, 1).error, "This pen is full. Open its management board to unlock more spaces.")
	assert_true(service.purchase(pen(COOP), 1, 20000).ok)
	assert_true(trading.buy(chicken, 1).ok)
	assert_eq(PenStatus.members(pen(COOP)).size(), 6)
	await wait_physics_frames(2)
	var wall: StaticBody2D = StaticBody2D.new()
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(1000, 1000)
	collider.shape = shape
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.add_child(collider)
	wall.position = pen(COOP).position + pen(COOP).bounds.get_center()
	world.add_child(wall)
	await wait_physics_frames(2)
	assert_eq(trading.quote_buy(chicken, 1).error, "A suitable pen is full or has no free space.")

func test_all_seven_species_have_thirty_arrival_positions_on_the_current_map() -> void:
	await wait_physics_frames(5)
	(pen(POND) as PondPen).rebuild_navigation()
	for id: StringName in [COOP, BARN, POND]:
		for level: int in range(1, 6):
			assert_true(service.purchase(pen(id), level, service.catalog.price(id, level)).ok)
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var trading: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, world.farming.time_manager)
	for offer: AnimalShopOffer in stock.animal_offers:
		var quote: Dictionary = trading.quote_buy(offer, 30)
		assert_true(quote.ok, str(offer.animal.animal_id))
		if quote.ok:
			assert_eq(quote.positions.size(), 30)

func test_full_legacy_schema_preserves_thirty_six_animals_without_charging() -> void:
	await wait_physics_frames(3)
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var trading: AnimalTradeService = AnimalTradeService.new(stock, world.player.wallet, world, world.farming.time_manager)
	assert_true(trading.buy(stock.animal_offers[0], 1).ok)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("legacy_pen_test", 1, world.farming.time_manager.now())
	var template: Dictionary = snapshot.animals[0]
	snapshot.animals = []
	for index: int in range(36):
		var row: Dictionary = template.duplicate(true)
		row.id = "legacy_chicken_%d" % index
		snapshot.animals.append(row)
	snapshot.version = 33
	snapshot.erase("pen_upgrades")
	var checked: Dictionary = SaveSchema.validate(snapshot, adapter.catalog)
	assert_true(checked.ok, str(checked))
	assert_eq(checked.snapshot.animals.size(), 36)
	assert_eq(checked.snapshot.coins, snapshot.coins)
	assert_eq(int(checked.snapshot.pen_upgrades[String(COOP)]), 6)
	assert_true(adapter.restore(checked.snapshot, float(snapshot.saved_at)).ok)
	assert_eq(pen(COOP).capacity, 30)
	assert_eq(PenStatus.members(pen(COOP)).size(), 36)
	assert_false(trading.quote_buy(stock.animal_offers[0], 1).ok)
	var restored: Dictionary = adapter.capture("legacy_pen_test", 2, float(snapshot.saved_at))
	assert_true(SaveSchema.validate(restored, adapter.catalog).ok)
	for actor: AnimalActor in PenStatus.members(pen(COOP)):
		actor.free()
	assert_eq(service.state.level(COOP), 6)

func test_upgrade_requests_save_and_failed_io_can_be_retried_without_spending_again() -> void:
	var manager: GameSaveManager = GameSaveManager.new()
	manager.autosave_seconds = 1000000.0
	add_child_autofree(manager)
	var repository: MemoryRepository = MemoryRepository.new()
	assert_true((await manager.bind_world(world, repository, "pen_purchase_test")).ok)
	var balance: int = world.player.wallet.balance
	assert_true(service.purchase(pen(COOP), 1, 20000).ok)
	await wait_process_frames(3)
	assert_eq(repository.writes, 1)
	assert_eq(int(repository.snapshot.pen_upgrades[String(COOP)]), 2)
	assert_eq(int(repository.snapshot.coins), balance - 20000)
	repository.fail_writes = true
	assert_true(service.purchase(pen(COOP), 2, 40000).ok)
	await wait_process_frames(3)
	assert_eq(repository.writes, 1)
	assert_eq(manager.revision, 1)
	assert_eq(pen(COOP).capacity, 15)
	assert_eq(world.player.wallet.balance, balance - 60000)
	repository.fail_writes = false
	assert_true((await manager.save_game()).ok)
	assert_eq(repository.writes, 2)
	assert_eq(int(repository.snapshot.pen_upgrades[String(COOP)]), 3)
	assert_eq(int(repository.snapshot.coins), balance - 60000)

func test_current_profile_copy_migrates_without_losing_animals_or_perennial_trees() -> void:
	var path: String = "res://docs/pen_upgrades_2026-10-26/legacy_profile.json"
	if not FileAccess.file_exists(path):
		pending("Local compatibility fixture is optional in clean checkouts")
		return
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var original: Dictionary = JSON.parse_string(str(envelope.payload)) as Dictionary
	var catalog: SaveCatalog = SaveCatalog.new()
	var checked: Dictionary = SaveSchema.validate(original, catalog)
	assert_true(checked.ok, str(checked))
	assert_eq(checked.snapshot.coins, original.coins)
	assert_eq(checked.snapshot.animals, original.animals)
	assert_eq(checked.snapshot.trees, original.trees)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	assert_true(adapter.restore(checked.snapshot, float(checked.snapshot.saved_at)).ok)
	assert_eq(world.trees.trees.size(), original.trees.size())
	var count: int = 0
	for id: StringName in [COOP, BARN, POND]:
		count += PenStatus.members(pen(id)).size()
	assert_eq(count, original.animals.size())
