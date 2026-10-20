extends GutTest
var wallet: WalletComponent
var bag: InventoryComponent
var catalog: ShopCatalog
var offer: ShopOffer
var service: ShopService

func before_each() -> void:
	wallet = WalletComponent.new()
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 2
	add_child_autofree(wallet)
	add_child_autofree(bag)
	catalog = ShopCatalog.new()
	offer = ShopOffer.new()
	offer.item = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	offer.price = 10
	catalog.offers.append(offer)
	service = ShopService.new(catalog, wallet, bag)

func test_purchase_commits_both_models_before_notifying_and_blocks_reentry() -> void:
	var observations: Array[int] = []
	var reentrant: Array[bool] = []
	bag.changed.connect(func() -> void:
		observations.append(wallet.balance)
		reentrant.append(bool(service.buy(offer, 1).ok)))
	assert_true(service.buy(offer, 3).ok)
	assert_eq(wallet.balance, 970)
	assert_eq(bag.count_item(&"carrot_seed"), 3)
	assert_eq(observations, [970])
	assert_eq(reentrant, [false])

func test_insufficient_coins_never_adds_items() -> void:
	wallet.set_balance(9)
	assert_false(service.buy(offer, 1).ok)
	assert_eq(wallet.balance, 9)
	assert_eq(bag.count_item(&"carrot_seed"), 0)

func test_full_bag_never_spends_or_partially_adds() -> void:
	bag.add(offer.item, 197)
	assert_false(service.buy(offer, 2).ok)
	assert_eq(wallet.balance, 1000)
	assert_eq(bag.count_item(&"carrot_seed"), 197)
	assert_true(service.buy(offer, 1).ok)
	assert_eq(bag.count_item(&"carrot_seed"), 198)
	assert_eq(wallet.balance, 990)

func test_invalid_quantities_or_foreign_offers_cannot_purchase() -> void:
	for amount: int in [-1, 0, 100, 1000000000]:
		assert_false(service.buy(offer, amount).ok)
	var foreign: ShopOffer = offer.duplicate() as ShopOffer
	assert_false(service.buy(foreign, 1).ok)
	offer.price = 0
	assert_false(service.buy(offer, 1).ok)
	assert_eq(wallet.balance, 1000)

func test_catalog_has_all_seeds_and_feed_once_with_valid_prices() -> void:
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var counts: Array[int] = [0, 0, 0]
	var ids: Dictionary = {}
	for entry: ShopOffer in stock.offers:
		assert_not_null(entry.item.icon)
		assert_gt(entry.price, 0)
		assert_false(ids.has(entry.item.item_id))
		ids[entry.item.item_id] = true
		counts[entry.category] += 1
	assert_eq(counts, [22, 2, 10])

func test_wallet_rejects_invalid_bounds_and_credit_overflow() -> void:
	assert_false(wallet.set_balance(-1))
	assert_false(wallet.credit(0))
	assert_false(wallet.credit(-10))
	assert_false(wallet.credit(WalletComponent.MAX_COINS))
	assert_eq(wallet.balance, 1000)
	assert_true(wallet.credit(50))
	assert_eq(wallet.balance, 1050)
