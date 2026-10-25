extends GutTest
var model: ChefCooking
var bag: InventoryComponent
const EGG: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
const DISH: ItemDefinition = preload("res://items/cooked/fried_egg.tres")

func before_each() -> void:
	model = ChefCooking.new()
	bag = InventoryComponent.new()
	bag.starting_tools = false
	add_child_autofree(bag)

func test_shipped_recipes_outputs_and_prices_are_allowlisted() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	assert_true(prices.is_valid())
	for recipe: CookingRecipe in ChefCooking.RECIPES:
		assert_true(recipe.valid())
		assert_eq(catalog.items[String(recipe.output.item_id)], recipe.output)
		if recipe.output.item_type == ItemDefinition.ItemType.PRODUCE:
			assert_not_null(prices.find(recipe.output.item_id))

func test_missing_ingredients_full_capacity_and_invalid_commands_never_spend() -> void:
	assert_eq(model.start("fried_egg", 1, bag, 100.0), "Not enough ingredients.")
	bag.add(EGG, 30)
	for amount: int in [0, -1, 21]:
		assert_ne(model.start("fried_egg", amount, bag, 100.0), "")
	assert_ne(model.start("unknown", 1, bag, 100.0), "")
	assert_eq(bag.count_item(EGG.item_id), 30)
	assert_eq(model.start("fried_egg", 20, bag, 100.0), "")
	assert_ne(model.start("fried_egg", 1, bag, 100.0), "")
	assert_eq(bag.count_item(EGG.item_id), 10)
	assert_eq(model.queue.size(), 20)

func test_serial_offline_boundary_and_repeated_advance_do_not_duplicate() -> void:
	bag.add(EGG, 3)
	assert_eq(model.start("fried_egg", 3, bag, 100.0), "")
	model.advance(14499.0)
	assert_eq(model.ready.size(), 0)
	model.advance(14500.0)
	assert_eq(model.ready.size(), 1)
	model.advance(14500.0)
	model.advance(50.0)
	assert_eq(model.ready.size(), 1)
	model.advance(1000000.0)
	assert_eq(model.ready.size(), 3)
	assert_eq(model.collect(bag, 1000000.0), 3)
	assert_eq(model.collect(bag, 1000000.0), 0)
	assert_eq(bag.count_item(DISH.item_id), 3)

func test_full_bag_keeps_ready_dishes_and_partial_collection_keeps_remainder() -> void:
	bag.add(EGG, 2)
	model.start("fried_egg", 2, bag, 100.0)
	model.advance(30000.0)
	for i: int in range(bag.slot_count):
		bag.add(EGG, EGG.get_stack_limit())
	assert_eq(model.collect(bag, 30000.0), 0)
	assert_eq(model.ready.size(), 2)
	bag.remove_from_slot(0, EGG.get_stack_limit())
	bag.add(DISH, DISH.get_stack_limit() - 1)
	assert_eq(model.collect(bag, 30000.0), 1)
	assert_eq(model.ready.size(), 1)

func test_multi_ingredient_batch_spends_atomically_and_blocks_reentrant_commands() -> void:
	var recipe: CookingRecipe = ChefCooking.find("bread")
	for i: int in range(recipe.ingredients.size()):
		bag.add(recipe.ingredients[i], recipe.amounts[i] * 2)
	watch_signals(bag)
	bag.changed.connect(func() -> void:
		assert_eq(model.queue.size(), 2)
		assert_true(model.busy)
		assert_ne(model.start("bread", 1, bag, 100.0), "")
		assert_eq(model.collect(bag, 100000.0), 0))
	assert_eq(model.start("bread", 2, bag, 100.0), "")
	assert_signal_emit_count(bag, "changed", 1)
	for ingredient: ItemDefinition in recipe.ingredients:
		assert_eq(bag.count_item(ingredient.item_id), 0)

func test_roundtrip_and_strict_validation() -> void:
	bag.add(EGG, 3)
	model.start("fried_egg", 3, bag, 100.0)
	var saved: Dictionary = model.capture(15000.0)
	assert_true(ChefCooking.valid(saved, 15000.0))
	var restored: ChefCooking = ChefCooking.new()
	restored.restore(saved, 30000.0)
	assert_eq(restored.ready.size(), 2)
	assert_eq(restored.queue.size(), 1)
	assert_eq(saved.ready.size(), 1)
	assert_false(ChefCooking.valid({"queue": [], "ready": ["unknown"], "updated_at": 0.0}, 100.0))
	assert_false(ChefCooking.valid({"queue": [], "ready": [], "updated_at": 101.0}, 100.0))
	saved.queue[0].finish_at = NAN
	assert_false(ChefCooking.valid(saved, 15000.0))

func test_all_five_recipes_can_be_cooked_collected_and_sold() -> void:
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	var wallet: WalletComponent = WalletComponent.new()
	add_child_autofree(wallet)
	wallet.set_balance(0)
	var seller: ProduceSaleService = ProduceSaleService.new(prices, wallet, bag)
	var expected: Array[int] = [18, 62, 165, 121, 946]
	for index: int in range(expected.size()):
		var recipe: CookingRecipe = ChefCooking.RECIPES[index]
		model = ChefCooking.new()
		for i: int in range(recipe.ingredients.size()):
			bag.add(recipe.ingredients[i], recipe.amounts[i])
		assert_eq(model.start(String(recipe.recipe_id), 1, bag, 100.0), "")
		assert_eq(model.collect(bag, 14500.0), 1)
		assert_eq(prices.find(recipe.output.item_id).price, expected[index])
		var sale: Dictionary = seller.sell(prices.find(recipe.output.item_id), 1)
		assert_true(sale.ok)
		assert_eq(sale.total, expected[index])
	assert_eq(wallet.balance, 1312)
