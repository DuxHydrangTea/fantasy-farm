extends GutTest
var wallet: WalletComponent
var bag: InventoryComponent
var catalog: ProducePriceCatalog
var carrot: ProducePrice
var milk: ProducePrice
var service: ProduceSaleService

func before_each() -> void:
	wallet = WalletComponent.new()
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 8
	add_child_autofree(wallet)
	add_child_autofree(bag)
	wallet.set_balance(1000)
	catalog = ProducePriceCatalog.new()
	carrot = ProducePrice.new()
	carrot.item = load("res://items/harvest_produces/carrot_produces.tres") as ItemDefinition
	carrot.price = 5
	milk = ProducePrice.new()
	milk.item = load("res://items/animal_produces/cow_milk.tres") as ItemDefinition
	milk.price = 24
	catalog.entries = [carrot, milk]
	service = ProduceSaleService.new(catalog, wallet, bag)

func test_quantity_sale_spans_stacks_and_keeps_other_inventory_items() -> void:
	bag.add(carrot.item, 120)
	bag.add(milk.item, 2)
	bag.add(InventoryComponent.HOE, 1)
	var result: Dictionary = service.sell(carrot, 105)
	assert_true(result.ok)
	assert_eq(result.total, 525)
	assert_eq(wallet.balance, 1525)
	assert_eq(bag.count_item(carrot.item.item_id), 15)
	assert_eq(bag.count_item(milk.item.item_id), 2)
	assert_eq(bag.count_item(&"hoe"), 1)

func test_sell_all_sells_all_accepted_types_and_keeps_seeds_feed_tools_and_unknown_produce() -> void:
	bag.add(carrot.item, 9)
	bag.add(milk.item, 2)
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	var feed: ItemDefinition = load("res://items/feeds/poultry_feed.tres") as ItemDefinition
	var unknown: ItemDefinition = load("res://items/flowers/flower_01.tres") as ItemDefinition
	bag.add(seed, 3)
	bag.add(feed, 1)
	bag.add(InventoryComponent.HOE, 1)
	bag.add(unknown, 1)
	var result: Dictionary = service.sell_all()
	assert_true(result.ok)
	assert_eq(result.quantity, 11)
	assert_eq(result.total, 93)
	assert_eq(wallet.balance, 1093)
	for item: ItemDefinition in [seed, feed, InventoryComponent.HOE, unknown]:
		assert_gt(bag.count_item(item.item_id), 0)
	assert_eq(service.owned_entries().size(), 0)

func test_invalid_quantities_insufficient_stock_and_foreign_offer_never_mutate_models() -> void:
	bag.add(carrot.item, 3)
	for count: int in [-1, 0, 4, 2147483647]:
		assert_false(service.sell(carrot, count).ok)
		assert_eq(wallet.balance, 1000)
		assert_eq(bag.count_item(carrot.item.item_id), 3)
	var forged: ProducePrice = carrot.duplicate() as ProducePrice
	forged.price = 1000000
	assert_false(service.sell(forged, 1).ok)
	assert_eq(bag.count_item(carrot.item.item_id), 3)

func test_rechecks_stock_at_checkout_and_repeated_sell_all_cannot_credit_again() -> void:
	bag.add(carrot.item, 5)
	assert_true(service.quote(carrot, 5).ok)
	bag.remove(carrot.item.item_id, 1)
	assert_false(service.sell(carrot, 5).ok)
	assert_eq(wallet.balance, 1000)
	assert_true(service.sell_all().ok)
	assert_false(service.sell_all().ok)
	assert_eq(wallet.balance, 1020)

func test_overflow_rejects_whole_batch_without_partial_sale() -> void:
	bag.add(carrot.item, 3)
	bag.add(milk.item, 2)
	wallet.set_balance(WalletComponent.MAX_COINS - 20)
	assert_false(service.sell_all().ok)
	assert_eq(bag.count_item(carrot.item.item_id), 3)
	assert_eq(bag.count_item(milk.item.item_id), 2)
	assert_eq(wallet.balance, WalletComponent.MAX_COINS - 20)
	assert_true(service.sell(carrot, 3).ok)
	assert_eq(wallet.balance, WalletComponent.MAX_COINS - 5)

func test_atomic_observers_and_reentrant_commands() -> void:
	bag.add(carrot.item, 10)
	var observed: Array[int] = []
	var reentered: Array[bool] = []
	bag.changed.connect(func() -> void:
		observed.append(wallet.balance)
		reentered.append(bool(service.sell_all().ok)))
	wallet.changed.connect(func(_balance: int) -> void:
		observed.append(bag.count_item(carrot.item.item_id))
		reentered.append(bool(service.sell(carrot, 1).ok)))
	assert_true(service.sell(carrot, 4).ok)
	assert_eq(observed, [1020, 6])
	assert_eq(reentered, [false, false])

func test_sell_all_rejects_non_produce_even_with_a_matching_id() -> void:
	var fake: ItemDefinition = ItemDefinition.new()
	fake.item_id = carrot.item.item_id
	fake.item_type = ItemDefinition.ItemType.SEED
	bag.add(fake, 2)
	assert_false(service.sell_all().ok)
	assert_eq(wallet.balance, 1000)
	assert_eq(bag.count_item(fake.item_id), 2)

func test_duplicate_prices_bad_catalog_and_empty_bag_reject_safely() -> void:
	assert_false(service.sell_all().ok)
	bag.add(carrot.item, 1)
	catalog.entries.append(carrot)
	assert_false(service.sell_all().ok)
	assert_eq(wallet.balance, 1000)
	assert_eq(bag.count_item(carrot.item.item_id), 1)

func test_authored_catalog_prices_every_current_produce_and_only_produce() -> void:
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	assert_true(prices.is_valid())
	assert_gte(prices.entries.size(), 48)
	for entry: ProducePrice in prices.entries:
		assert_eq(entry.item.item_type, ItemDefinition.ItemType.PRODUCE)
		assert_gte(entry.price, 1)
