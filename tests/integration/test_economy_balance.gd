extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var adapter: WorldStateAdapter

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	await wait_physics_frames(3)
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())

func test_crop_purchase_harvest_sale_and_first_land_milestones() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var wallet: WalletComponent = world.player.wallet
	assert_eq(wallet.balance, 10000)
	var shop: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var offer: ShopOffer
	for candidate: ShopOffer in shop.offers:
		if candidate.item.item_id == &"carrot_seed":
			offer = candidate
	assert_true(ShopService.new(shop, wallet, bag).buy(offer, 1).ok)
	assert_eq(wallet.balance, 7300)
	var definition: CropDefinition = offer.item.crop as CropDefinition
	assert_eq(definition.growth_seconds, 60.0)
	var now: float = TimeManager.now()
	var cell: Vector2i = Vector2i(56, 20)
	world.farming.restore_crop(cell, definition, now - 61, now - 1, 1, now)
	var before: int = bag.count_item(&"carrot_produces")
	assert_true(world.farming.harvest(cell, bag))
	assert_eq(bag.count_item(&"carrot_produces"), before + 100)
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	var sale: ProduceSaleService = ProduceSaleService.new(prices, wallet, bag)
	assert_true(sale.sell(prices.find(&"carrot_produces"), 100).ok)
	assert_eq(wallet.balance, 10800)
	wallet.set_balance(87000)
	assert_true(world.land.state.purchase(wallet, 4).ok)
	assert_eq(wallet.balance, 27000)
	assert_eq(world.land.state.next_price(), 150000)
	world.land.state.restore_columns(3)
	assert_eq(world.land.state.next_price(), 350000)

func test_new_orders_match_npc_multiplier_and_large_deliveries_are_atomic() -> void:
	var orders: OrderService = world.orders.service
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	assert_eq(orders.catalog.entries.size(), 6)
	for entry: OrderDefinition in orders.catalog.entries:
		var value: int = 0
		for index: int in range(entry.items.size()):
			value += prices.find(entry.items[index].item_id).price * entry.amounts[index]
		assert_eq(entry.reward_coins, value * (125 if entry.items.size() == 1 else 140) / 100)
		assert_true(OrderAvailability.new(world).allows(entry))
	var serial: int = int(orders.capture().slots[0].serial)
	var entry: OrderDefinition = orders.definition(serial)
	for index: int in range(entry.items.size()):
		orders.inventory.add(entry.items[index], entry.amounts[index])
	var before: int = orders.wallet.balance
	assert_true(orders.deliver(serial).ok)
	assert_eq(orders.wallet.balance, before + entry.reward_coins)
	assert_false(orders.deliver(serial).ok)

func test_v15_roundtrip_preserves_issued_orders_assets_timers_and_feed_units() -> void:
	var now: float = TimeManager.now()
	var old: Dictionary = adapter.capture("economy_test", 1, now)
	old.version = 15
	old.coins = 12345
	old.inventory[5] = {"item": "cow_milk", "count": 32000}
	old.trees = [{"tree": "apple", "cell": [12, 61], "planted_at": now - 60, "growth_started_at": now - 60, "matures_at": now + 120, "last_at": now, "fruit_work": 0.0}]
	var legacy: OrderCatalog = load("res://resources/orders/legacy_orders_v15.tres") as OrderCatalog
	var service: OrderService = OrderService.new(world.player.selection.inventory, world.player.wallet, func(_entry: OrderDefinition) -> bool: return true, legacy)
	service.initialize()
	old.orders = service.capture()
	old.orders.cursor = 7
	var kept: Array = []
	var total_units: int = 0
	for row: Dictionary in old.troughs:
		if String(row.id).ends_with("_02"):
			continue
		if row.id == "placed_1563140842":
			row.stock = 600
			row.feed_reserve = 250
		total_units += int(row.stock) + int(row.feed_reserve)
		kept.append(row)
	old.troughs = kept
	var original: Dictionary = old.duplicate(true)
	var checked: Dictionary = adapter.preflight(old)
	assert_true(checked.ok, str(checked))
	assert_eq(old, original, "Migration must not alter the caller or backup")
	if not checked.ok:
		return
	assert_eq(checked.snapshot.version, SaveSchema.VERSION)
	assert_true(adapter.restore(old, now).ok)
	assert_eq(world.player.wallet.balance, 12345)
	assert_eq(world.player.selection.inventory.count_item(&"cow_milk"), 32000)
	var restored: Dictionary = adapter.capture("economy_test", 2, now)
	assert_eq(restored.animals.size(), original.animals.size())
	assert_eq(restored.trees[0].matures_at, original.trees[0].matures_at)
	var after_units: int = 0
	for row: Dictionary in restored.troughs:
		after_units += int(row.stock) + int(row.feed_reserve)
	assert_eq(after_units, total_units)
	var serial: int = int(world.orders.service.capture().slots[0].serial)
	var issued: OrderDefinition = world.orders.service.definition(serial)
	assert_eq(issued.order_id, &"carrot_crate")
	assert_eq(issued.amounts, [12])
	assert_eq(issued.reward_coins, 72)
	assert_true(adapter.restore(restored, now).ok, "Migrated timers must remain loadable on subsequent saves")

func test_all_pens_have_24_hour_capacity_when_filled_with_new_needs() -> void:
	for board: PenBoard in world.pen_boards:
		for kind: AnimalTrough.Kind in [AnimalTrough.Kind.FOOD, AnimalTrough.Kind.WATER]:
			var status: Dictionary = PenStatus.troughs(board.pen, kind)
			assert_eq(status.capacity, 2400)
			assert_gte(status.capacity, board.pen.capacity * 60)
	for definition: AnimalDefinition in adapter.catalog.animals.values():
		assert_eq(definition.satiety_depletion_seconds, 3600.0)
		assert_eq(definition.hydration_depletion_seconds, 3600.0)

func test_invalid_v15_orders_or_duplicate_troughs_are_rejected_without_mutation() -> void:
	var old: Dictionary = adapter.capture("economy_test", 1, TimeManager.now())
	old.version = 15
	old.orders = OrderSaveSchema.fresh()
	old.orders.slots[0] = {"serial": 1, "template": "unknown_order"}
	var coins: int = world.player.wallet.balance
	assert_false(adapter.restore(old, TimeManager.now()).ok)
	assert_eq(world.player.wallet.balance, coins)
	old.orders = OrderSaveSchema.fresh()
	old.troughs.append(old.troughs[0].duplicate(true))
	assert_false(adapter.restore(old, TimeManager.now()).ok)


func test_fruit_and_timber_use_new_yields_and_keep_one_batch_and_regrowth() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var fruit: FruitTree = FruitTree.new()
	fruit.definition = load("res://trees/definitions/apple.tres") as TreeDefinition
	fruit.initialize(1000.0)
	add_child_autofree(fruit)
	assert_true(fruit.water(1000.0))
	fruit.refresh(1000.0 + 43200 + 14400 * 10)
	var before: int = bag.count_item(&"apple")
	assert_true(fruit.harvest(bag))
	assert_eq(bag.count_item(&"apple"), before + 300)
	assert_false(fruit.harvest(bag), "Offline work is capped at one fruit batch")
	var timber: TimberTree = TimberTree.new()
	timber.definition = load("res://trees/definitions/oak.tres") as TreeDefinition
	timber.initialize(1000.0)
	add_child_autofree(timber)
	timber.refresh(87400.0)
	before = bag.count_item(&"wood")
	for hit: int in range(4):
		assert_true(timber.chop(bag))
	assert_eq(bag.count_item(&"wood"), before + 400)
	assert_eq(bag.count_item(&"oak_sapling"), 1)
	timber.refresh(87520.0)
	assert_false(timber.is_mature())
	timber.refresh(87520.0 + 43200)
	assert_true(timber.is_mature())
