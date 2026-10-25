extends GutTest
var bag: InventoryComponent
var produce: ItemDefinition

func before_each() -> void:
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 2
	add_child_autofree(bag)
	produce = ItemDefinition.new()
	produce.item_id = &"quality_test"
	produce.item_type = ItemDefinition.ItemType.PRODUCE
	produce.max_stack = 5

func test_tiers_share_stack_capacity_and_spill_without_loss() -> void:
	assert_eq(bag.add(produce, 3, 1), 3)
	assert_eq(bag.add(produce, 4, 2), 4)
	assert_eq(bag.slot(0).tiers, [0, 3, 2])
	assert_eq(bag.slot(1).tiers, [0, 0, 2])
	assert_eq(bag.capacity_for(produce), 3)
	assert_eq(bag.add(produce, 9), 3)
	assert_eq(bag.count_item(produce.item_id, -1), 10)

func test_default_consumption_never_spends_silver_or_gold() -> void:
	bag.add(produce, 2)
	bag.add(produce, 3, 1)
	bag.add(produce, 4, 2)
	assert_eq(bag.remove(produce.item_id, 8), 2)
	assert_eq(bag.count_item(produce.item_id, 1), 3)
	assert_eq(bag.count_item(produce.item_id, 2), 4)
	assert_false(bag.has(produce.item_id, 5, 1))
	assert_eq(bag.consume(produce.item_id, 5, ItemQuality.exact(1)), [0, 3, 0])
	assert_eq(bag.count_item(produce.item_id, 2), 4)

func test_explicit_set_orders_tiers_globally_across_slots() -> void:
	bag.add(produce, 4, 2)
	bag.add(produce, 4, 1)
	assert_eq(bag.consume(produce.item_id, 5, ItemQuality.tier_set([1, 2])), [0, 4, 1])
	assert_eq(bag.consume(produce.item_id, 2, ItemQuality.tier_set([1])), [0, 0, 0])
	assert_eq(bag.consume(produce.item_id, 2, ItemQuality.tier_set([1, 2], true)), [0, 0, 2])

func test_move_and_partial_transfer_preserve_every_tier() -> void:
	bag.add(produce, 3, 1)
	bag.add(produce, 4, 2)
	assert_true(bag.move_slot(0, 1))
	assert_eq(bag.count_item(produce.item_id, 1), 3)
	assert_eq(bag.count_item(produce.item_id, 2), 4)
	var target: InventoryComponent = InventoryComponent.new()
	target.starting_tools = false
	target.slot_count = 1
	add_child_autofree(target)
	target.add(produce, 3)
	assert_eq(bag.transfer_slot_to(1, target, 5), 2)
	assert_eq(target.count_item(produce.item_id, -1), 5)
	assert_eq(target.count_item(produce.item_id, 1), 2)
	assert_eq(bag.count_item(produce.item_id, 1), 1)
	assert_eq(bag.count_item(produce.item_id, 2), 4)

func test_snapshots_are_deep_and_corrupt_tiers_rejected_atomically() -> void:
	bag.add(produce, 3, 1)
	var copy: Dictionary = bag.slot(0)
	copy.tiers[1] = 99
	assert_eq(bag.slot(0).tiers, [0, 3, 0])
	assert_false(bag.replace_slots([copy, bag.slot(1)]))
	assert_eq(bag.count_item(produce.item_id, 1), 3)
	assert_false(ItemQuality.valid_tiers([0, -1, 4], produce, 3))
	assert_false(ItemQuality.valid_tiers([0, 1.5, 1.5], produce, 3))
	assert_eq(bag.add(InventoryComponent.HOE, 1, 2), 0)

func test_sale_only_spends_selected_tier_and_uses_quality_price() -> void:
	var carrot: ItemDefinition = load("res://items/harvest_produces/carrot_produces.tres") as ItemDefinition
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	var wallet: WalletComponent = WalletComponent.new()
	add_child_autofree(wallet)
	wallet.set_balance(0)
	bag.add(carrot, 2, 1)
	bag.add(carrot, 1, 2)
	var sales: ProduceSaleService = ProduceSaleService.new(prices, wallet, bag)
	assert_false(sales.sell_all().ok)
	sales.tier = 1
	var price: ProducePrice = prices.find(carrot.item_id)
	assert_eq(sales.quote_all().total, 2 * ItemQuality.unit_price(price.price, 1))
	assert_true(sales.sell_all().ok)
	assert_eq(bag.count_item(carrot.item_id, 2), 1)
	assert_eq(wallet.balance, 2 * ItemQuality.unit_price(price.price, 1))

func test_chef_does_not_substitute_quality_and_can_craft_root_tonic() -> void:
	var recipe: CookingRecipe = ChefCooking.find("bread")
	for i: int in range(recipe.ingredients.size()):
		bag.add(recipe.ingredients[i], recipe.amounts[i], 1)
	var chef: ChefCooking = ChefCooking.new()
	assert_eq(chef.quote("bread", 1, bag), "Not enough ingredients.")
	var roots: ItemDefinition = load("res://items/trees/root_wood.tres") as ItemDefinition
	bag.remove_from_slot(0, 100, false, 1)
	bag.add(roots, 1)
	assert_eq(chef.start("root_tonic", 1, bag, 100), "")
	assert_eq(chef.collect(bag, 160), 1)
	assert_eq(bag.count_item(&"root_tonic"), 1)
