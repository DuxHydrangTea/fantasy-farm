extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var garden: FlowerGarden
var adapter: WorldStateAdapter

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	await wait_physics_frames(2)
	garden = world.get_node("FlowerGarden") as FlowerGarden
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())

func _snapshot() -> Dictionary:
	return adapter.capture("starter_test", 1, TimeManager.now())

func _unlock() -> void:
	world.player.wallet.set_balance(87000)
	assert_true(world.land.state.purchase(world.player.wallet, 4).ok)
	assert_eq(world.player.wallet.balance, 27000)

func _flower_pickups(data: Dictionary) -> Array:
	return data.pickups.filter(func(row: Dictionary) -> bool: return String(row.item).begins_with("flower_") and String(row.item).ends_with("_seed"))

func test_new_profile_has_no_free_animals_flowers_or_seeds() -> void:
	var data: Dictionary = _snapshot()
	assert_eq(data.animals.size(), 0)
	assert_eq(data.coins, 10000)
	assert_eq(data.land_columns, 4)
	assert_eq(data.land_starting_columns, 4)
	assert_eq(world.land.state.next_price(), 60000)
	var open_cells: int = 0
	for y: int in range(19, 53):
		for x: int in range(9, 57):
			if world.land.state.is_unlocked(Vector2i(x, y)):
				open_cells += 1
	assert_eq(open_cells, 136)
	assert_false(data.flower_garden_unlocked)
	assert_true(garden.starter_content_locked)
	assert_eq(data.flower_gardens[0].flowers.size(), 0)
	assert_eq(_flower_pickups(data).size(), 0)
	assert_eq(world.player.selection.inventory.count_item(&"carrot_seed"), 24)
	assert_false(world.objectives.progress.ready_to_claim())
	for x: int in range(53, 57):
		assert_true(world.farming.till(Vector2i(x, 30)), "Each starting column can actually be tilled")
	assert_false(world.farming.till(Vector2i(52, 30)), "The fifth column still requires purchase")

func test_locked_pot_does_not_consume_purchased_seed() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var seed: ItemDefinition = load("res://items/seeds/flower_01_seed.tres") as ItemDefinition
	bag.add(seed, 1)
	var index: int = -1
	for slot: int in range(bag.slot_count):
		if bag.get_slot_item(slot) == seed:
			index = slot
	var pot: FlowerPot = garden.pots.values()[0]
	assert_false(pot.can_plant(seed))
	assert_false(pot.plant(bag, index, TimeManager.now()))
	assert_false(pot.can_water())
	assert_eq(bag.count_item(seed.item_id), 1)
	assert_null(pot.definition)
	assert_false(OrderAvailability.new(world)._has_source(&"flower_01"))
	world.player.selection.select_slot(index)
	world.player.global_position = pot.global_position + Vector2.UP * 16.0
	world.player.animation.face(Vector2.DOWN)
	var interaction: FlowerInteraction = world.player.get_node("FlowerInteraction") as FlowerInteraction
	interaction.refresh()
	assert_false(interaction.prompt.visible, "The garden notice replaces repeated pot prompts")
	assert_eq(interaction.prepare_action(&"plant"), &"blocked")

func test_first_land_grants_sixty_seeds_once_without_preplanted_flowers() -> void:
	_unlock()
	assert_false(garden.starter_content_locked)
	assert_true(OrderAvailability.new(world)._has_source(&"flower_01"))
	var data: Dictionary = _snapshot()
	var gifts: Array = _flower_pickups(data)
	assert_eq(gifts.size(), 10)
	var total: int = 0
	for row: Dictionary in gifts:
		total += int(row.amount)
	assert_eq(total, 60)
	assert_eq(data.flower_gardens[0].flowers.size(), 0)
	world.starter_content.refresh()
	assert_eq(_flower_pickups(_snapshot()).size(), 10)
	# A claimed/removed gift must stay absent after repeat loads.
	data.pickups = data.pickups.filter(func(row: Dictionary) -> bool: return row.id != gifts[0].id)
	assert_true(adapter.restore(data, TimeManager.now()).ok)
	assert_true(adapter.restore(_snapshot(), TimeManager.now()).ok)
	assert_eq(_flower_pickups(_snapshot()).size(), 9)

func test_locked_profile_roundtrip_and_invalid_flag_are_transactional() -> void:
	var data: Dictionary = _snapshot()
	assert_true(adapter.restore(data, TimeManager.now()).ok)
	assert_true(garden.starter_content_locked)
	assert_eq(_flower_pickups(_snapshot()).size(), 0)
	var bad: Dictionary = data.duplicate(true)
	bad.flower_garden_unlocked = "true"
	bad.coins = 999999
	assert_false(adapter.restore(bad, TimeManager.now()).ok)
	assert_eq(world.player.wallet.balance, int(data.coins))
	assert_false(world.starter_content.flower_garden_unlocked)
	assert_eq(world.land.state.starting_columns, 4)
	assert_eq(world.land.state.next_price(), 60000)

func test_v19_keeps_original_land_and_inventory_without_granting_new_starter_items() -> void:
	var data: Dictionary = _snapshot()
	data.version = 19
	data.erase("land_starting_columns")
	data.land_columns = 1
	for row: Dictionary in data.inventory:
		if row.item == "carrot_seed":
			row.count = 7
	var checked: Dictionary = SaveSchema.validate(data, adapter.catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.land_columns, 1)
	assert_eq(checked.snapshot.land_starting_columns, 1)
	assert_false(data.has("land_starting_columns"))
	assert_true(adapter.restore(data, TimeManager.now()).ok)
	assert_eq(world.player.selection.inventory.count_item(&"carrot_seed"), 7)
	assert_eq(world.land.state.unlocked_columns, 1)
	assert_eq(world.land.state.next_price(), 60000)
	assert_true(garden.starter_content_locked)
	world.player.wallet.set_balance(60000)
	assert_true(world.land.state.purchase(world.player.wallet, 1).ok)
	assert_false(garden.starter_content_locked)
	assert_eq(world.land.state.next_price(), 150000)

func test_v16_save_keeps_animals_flowers_inventory_and_unlocked_garden() -> void:
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
	garden.starter_flowers_added = false
	garden.add_starter_flowers(TimeManager.now())
	garden.restore_initial_supplies()
	var shop: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	world.player.wallet.set_balance(100000)
	var trade: AnimalTradeService = AnimalTradeService.new(shop, world.player.wallet, world, world.farming.time_manager)
	assert_true(trade.buy(shop.animal_offers[0], 1).ok)
	var data: Dictionary = _snapshot()
	data.version = 16
	data.erase("flower_garden_unlocked")
	assert_true(adapter.restore(data, TimeManager.now()).ok)
	var restored: Dictionary = _snapshot()
	assert_true(restored.flower_garden_unlocked)
	assert_eq(restored.land_columns, 4)
	assert_eq(restored.animals.size(), 1)
	assert_eq(restored.animals[0].id, data.animals[0].id)
	assert_eq(restored.coins, data.coins)
	assert_eq(restored.inventory, data.inventory)
	assert_eq(restored.flower_gardens[0].flowers.size(), 8)
	assert_eq(_flower_pickups(restored).size(), 10)
	assert_false(data.has("flower_garden_unlocked"))

func test_capture_during_wallet_signal_observes_committed_reward() -> void:
	var captures: Array[Dictionary] = []
	world.player.wallet.set_balance(87000)
	world.player.wallet.changed.connect(func(_balance: int) -> void: captures.append(_snapshot()))
	assert_true(world.land.state.purchase(world.player.wallet, 4).ok)
	assert_eq(captures.size(), 1)
	assert_true(captures[0].flower_garden_unlocked)
	assert_eq(_flower_pickups(captures[0]).size(), 10)

func test_twenty_four_carrots_and_five_rewards_reach_129000_then_first_land() -> void:
	var clock: FarmClock = FarmClock.new()
	var time: Dictionary = {"now": TimeManager.now()}
	clock.clock_source = func() -> float: return float(time.now)
	add_child_autofree(clock)
	world.farming.time_manager = clock
	var bag: InventoryComponent = world.player.selection.inventory
	var goals: ObjectiveProgress = world.objectives.progress
	for index: int in range(24):
		var cell: Vector2i = Vector2i(56, 20 + index)
		world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell + Vector2i.UP))
		world.player.animation.face(Vector2.DOWN)
		assert_true(world.farming.till(cell, world.player))
		if index == 0:
			assert_true(goals.claim(&"first_soil").ok)
		assert_true(world.farming.plant(cell, bag, 2, world.player))
		if index == 0:
			assert_true(goals.claim(&"first_seed").ok)
		assert_true(world.farming.water(cell, world.player))
		if index == 0:
			assert_true(goals.claim(&"first_water").ok)
	time.now = float(time.now) + 61.0
	for index: int in range(24):
		assert_true(world.farming.harvest(Vector2i(56, 20 + index), bag))
		if index == 0:
			assert_true(goals.claim(&"first_harvest").ok)
	assert_eq(bag.count_item(&"carrot_produces"), 2400)
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	var sales: ProduceSalesUI = buyer.menu as ProduceSalesUI
	assert_true(sales.open(buyer, world.player))
	assert_true(sales.service.sell(sales.catalog.find(&"carrot_produces"), 2400).ok)
	sales.close(false)
	assert_true(goals.claim(&"first_sale").ok)
	assert_eq(world.player.wallet.balance, 129000)
	assert_false(goals.ready_to_claim(), "No free animal completes the next goal")
	assert_true(world.land.state.purchase(world.player.wallet, 4).ok)
	assert_eq(world.player.wallet.balance, 69000)
	assert_false(garden.starter_content_locked)
