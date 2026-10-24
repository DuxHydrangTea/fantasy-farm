extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var goals: ObjectiveProgress
var adapter: WorldStateAdapter
var catalog: SaveCatalog
var cell: Vector2i = Vector2i(56, 20)

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	await wait_physics_frames(2)
	goals = world.objectives.progress
	catalog = SaveCatalog.new()
	adapter = WorldStateAdapter.new(world, catalog)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell + Vector2i.UP))
	world.player.animation.face(Vector2.DOWN)

func _advance_to(id: StringName) -> void:
	while goals.active() != null and goals.active().objective_id != id:
		var step: ObjectiveDefinition = goals.active()
		if step.state_condition:
			if step.condition == &"prepared_soil":
				world.farming.till(cell, world.player)
			if step.condition == &"own_animal":
				var shop: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
				var trade: AnimalTradeService = AnimalTradeService.new(shop, world.player.wallet, world, world.farming.time_manager)
				assert_true(trade.buy(shop.animal_offers[0], 1).ok)
			goals.refresh_state()
		else:
			goals.record(step.condition)
		assert_true(goals.claim(step.objective_id).ok)

func test_actual_farming_commits_count_but_invalid_actions_and_rain_do_not() -> void:
	assert_false(world.farming.till(Vector2i(-1, -1), world.player))
	assert_eq(goals.progress(), 0)
	assert_true(world.farming.till(cell, world.player))
	assert_true(goals.ready_to_claim())
	assert_true(goals.claim(&"first_soil").ok)
	assert_false(world.farming.plant(cell, world.player.selection.inventory, 0, world.player))
	assert_eq(goals.progress(), 0)
	assert_true(world.farming.plant(cell, world.player.selection.inventory, 2, world.player))
	assert_true(goals.claim(&"first_seed").ok)
	world.farming.rain_water()
	assert_eq(goals.progress(), 0, "Rain is not manual watering")
	world.farming.evaporate_soil(FarmingController.SOIL_MOISTURE_SECONDS + 1)
	assert_true(world.farming.water(cell, world.player))
	assert_true(goals.ready_to_claim())
	assert_false(world.farming.water(cell, world.player))
	assert_true(goals.claim(&"first_water").ok)
	var crop: Crop = world.farming.get_crop(cell)
	assert_false(world.farming.harvest(cell, world.player.selection.inventory))
	assert_eq(goals.progress(), 0)
	var now: float = world.farming.time_manager.now()
	crop.restore_progress(crop.definition, now - 100, now - 1, 1, now)
	assert_true(world.farming.harvest(cell, world.player.selection.inventory))
	assert_eq(goals.progress(), 1)
	assert_false(world.farming.harvest(cell, world.player.selection.inventory))
	assert_true(goals.claim(&"first_harvest").ok)

func test_sale_service_hooks_each_visit_once_and_ignores_inventory_grants() -> void:
	_advance_to(&"first_sale")
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	var sales: ProduceSalesUI = buyer.menu as ProduceSalesUI
	var item: ProducePrice = sales.catalog.entries[0]
	world.player.selection.inventory.add(item.item, 5)
	assert_eq(goals.progress(), 0)
	for iteration: int in range(2):
		world.objectives.setup() # Repeated composition must not duplicate subscriptions.
		assert_true(sales.open(buyer, world.player))
		assert_false(sales.service.sell(item, 99).ok)
		assert_eq(goals.progress(), iteration)
		if iteration == 0:
			assert_true(sales.service.sell(item, 1).ok)
			assert_eq(goals.progress(), 1)
		assert_eq(sales.service.sold.get_connections().size(), 1)
		sales.close(false)
	assert_true(goals.claim(&"first_sale").ok)
	assert_false(goals.ready_to_claim(), "A fresh farm must buy its first animal")

func test_trough_refill_counts_at_impact_only_and_stock_restore_does_not_count() -> void:
	_advance_to(&"first_feed")
	var trough: AnimalTrough
	for node: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
		if world.is_ancestor_of(node) and (node as AnimalTrough).kind == AnimalTrough.Kind.FOOD:
			trough = node as AnimalTrough
			break
	assert_not_null(trough)
	trough.stock = 0
	trough.refill(10)
	assert_eq(goals.progress(), 0)
	world.player.global_position = trough.global_position + Vector2(0, 20)
	world.player.animation.face(Vector2.UP)
	world.player.interactions.execute(InteractionTarget.new(trough, InteractionTarget.Kind.TROUGH, world.player))
	assert_eq(goals.progress(), 0)
	await wait_seconds(0.9)
	assert_eq(goals.progress(), 1)
	assert_true(goals.claim(&"first_feed").ok)
	assert_eq(goals.progress(), 0, "Feed commit cannot count as water refill")
	for node: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
		if world.is_ancestor_of(node) and (node as AnimalTrough).kind == AnimalTrough.Kind.WATER:
			trough = node as AnimalTrough
			break
	trough.stock = 0
	world.player.global_position = trough.global_position + Vector2(0, 20)
	world.player.animation.face(Vector2.UP)
	world.player.interactions.execute(InteractionTarget.new(trough, InteractionTarget.Kind.TROUGH, world.player))
	await wait_seconds(0.9)
	assert_true(goals.ready_to_claim())
	assert_true(goals.claim(&"first_trough_water").ok)
	assert_false(goals.ready_to_claim())
	world.player.global_position = world.land.interaction_position() + Vector2(0, 20)
	world.player.wallet.set_balance(100000)
	assert_true(world.land.purchase(world.land.state.unlocked_columns).ok)
	assert_true(goals.ready_to_claim())
	assert_true(goals.claim(&"first_expansion").ok)
	assert_null(goals.active())

func test_snapshot_roundtrip_migration_atomic_claim_and_rollback() -> void:
	assert_true(world.farming.till(cell, world.player))
	var pending: Dictionary = adapter.capture("objective_test", 1, TimeManager.now())
	assert_true(SaveSchema.validate(pending, catalog).ok)
	var observed: Array = []
	world.player.wallet.changed.connect(func(_balance: int) -> void:
		observed.append(adapter.capture("objective_test", 2, TimeManager.now()))
	, CONNECT_ONE_SHOT)
	assert_true(goals.claim(&"first_soil").ok)
	var claimed: Dictionary = adapter.capture("objective_test", 2, TimeManager.now())
	assert_true(observed[0].objectives.steps[0].claimed)
	assert_eq(observed[0].coins, claimed.coins)
	var folder: String = "res://.godot/objective_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repo: LocalSaveRepository = LocalSaveRepository.new(folder, catalog)
	assert_true((await repo.write_profile_async("objective_test", pending, 0)).ok)
	var disk: Dictionary = repo.read_profile("objective_test")
	assert_true(disk.ok)
	assert_eq(disk.snapshot.objectives, JSON.parse_string(JSON.stringify(pending.objectives)))
	assert_true((await repo.write_profile_async("objective_test", claimed, 1)).ok)
	disk = repo.read_profile("objective_test")
	assert_eq(disk.snapshot.objectives, JSON.parse_string(JSON.stringify(claimed.objectives)))
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(repo.path("objective_test") + suffix):
			DirAccess.remove_absolute(repo.path("objective_test") + suffix)
	DirAccess.remove_absolute(folder)
	assert_eq(claimed.coins, pending.coins + ObjectiveProgress.DEFAULT_CATALOG.steps[0].reward_coins)
	assert_true(adapter.restore(pending, TimeManager.now()).ok)
	assert_eq(world.player.wallet.balance, int(pending.coins))
	assert_true(goals.ready_to_claim())
	assert_true(adapter.restore(claimed, TimeManager.now()).ok)
	assert_false(goals.claim(&"first_soil").ok)
	assert_eq(world.player.wallet.balance, int(claimed.coins))
	var legacy: Dictionary = pending.duplicate(true)
	legacy.version = 11
	legacy.erase("objectives")
	var checked: Dictionary = SaveSchema.validate(legacy, catalog)
	assert_true(checked.ok)
	assert_false(legacy.has("objectives"))
	assert_eq(checked.snapshot.inventory, legacy.inventory)
	assert_eq(checked.snapshot.animals, legacy.animals)
	assert_eq(checked.snapshot.coins, legacy.coins)
	assert_true(adapter.restore(legacy, TimeManager.now()).ok)
	assert_eq(goals.active().objective_id, &"first_soil")
	assert_eq(goals.progress(), 1, "Legacy tilled soil satisfies preparation without granting a reward")

func test_bad_progress_rejected_in_preflight_without_suspending_or_mutating_world() -> void:
	var snapshot: Dictionary = adapter.capture("objective_test", 1, TimeManager.now())
	var bad: Dictionary = snapshot.duplicate(true)
	bad.objectives.steps[1].progress = 1
	assert_false(adapter.restore(bad, TimeManager.now()).ok)
	assert_false(goals.suspended)
	assert_eq(world.player.wallet.balance, int(snapshot.coins))
	assert_eq(goals.capture(), snapshot.objectives)
	bad = snapshot.duplicate(true)
	bad.erase("objectives")
	assert_false(SaveSchema.validate(bad, catalog).ok)
	bad = snapshot.duplicate(true)
	bad.inventory[0].item = "missing_item"
	assert_false(adapter.restore(bad, TimeManager.now()).ok)
	assert_false(goals.suspended)

func test_fresh_profile_baseline_and_land_owned_before_activation() -> void:
	var inventory: InventoryComponent = world.player.selection.inventory
	var seed: ItemDefinition = inventory.get_slot_item(2)
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	var price: ProducePrice = prices.find((seed.crop.harvest_item as ItemDefinition).item_id)
	var animals: int = 0
	for pen: Node in world.get_children():
		if pen is AnimalPen:
			for actor: Node in pen.get_children():
				if actor is AnimalActor:
					animals += 1
	print("OBJECTIVE_BASELINE=" + JSON.stringify({"coins": world.player.wallet.balance, "land_columns": world.land.state.unlocked_columns,
		"seed": String(seed.item_id), "seed_count": inventory.get_slot_count(2), "growth_seconds": seed.crop.growth_seconds,
		"harvest_amount": seed.crop.harvest_amount, "produce_sell_price": price.price, "animals": animals,
		"first_land_price": world.land.state.next_price(), "objective_rewards": 775}))
	assert_eq(world.player.wallet.balance, WalletComponent.STARTING_COINS)
	world.land.state.restore_columns(2)
	_advance_to(&"first_expansion")
	assert_true(goals.ready_to_claim())

func test_fully_prepared_legacy_farm_is_not_stuck_on_an_impossible_till_action() -> void:
	world.land.state.restore_columns(48)
	var rows: Array = []
	for y: int in range(LandExpansionState.REGION.position.y, LandExpansionState.REGION.end.y):
		for x: int in range(LandExpansionState.REGION.position.x, LandExpansionState.REGION.end.x):
			rows.append({"cell": [x, y], "state": FarmingController.Soil.DRY, "moisture": 0.0})
	world.farming.restore_soil(rows)
	assert_false(world.farming.can_till(cell, world.player))
	goals.refresh_state()
	assert_true(goals.ready_to_claim())
	assert_eq(world.player.wallet.balance, WalletComponent.STARTING_COINS, "Observing existing soil never grants a reward")
	assert_true(goals.claim(&"first_soil").ok)
	assert_eq(goals.active().objective_id, &"first_seed")
