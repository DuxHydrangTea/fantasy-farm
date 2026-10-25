extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
var world: FarmWorld
var service: WorkerService
var source: InventoryComponent
var clock: Array[float]
var now: float
var original_clock: Callable
var original_clock_floor: float
var cell: Vector2i = Vector2i(48, 30)

func before_each() -> void:
	original_clock = TimeManager.clock_source
	original_clock_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(1000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	now = world.farming.time_manager.now()
	clock = [now]
	var manual_clock: Array[float] = clock
	world.farming.time_manager.clock_source = func() -> float: return manual_clock[0]
	world.farming.restore_soil([])
	service = world.workers
	source = world.storages.inventory("farm_supply_storage")
	assert_eq(service.hire("crop"), "")
	_limit([cell, cell + Vector2i.RIGHT])

func after_each() -> void:
	world.farming.time_manager.clock_source = original_clock
	world.farming.time_manager._last_timestamp = original_clock_floor

func _limit(cells: Array[Vector2i]) -> void:
	service.crop_policy.cells = cells.duplicate()
	service.crop_policy.cached_columns = world.land.state.unlocked_columns
	service.crop_policy.soils.clear()
	for point: Vector2i in cells:
		service.crop_policy.soils[point] = int(world.farming.get_soil_state(point))

func _commit(job: Dictionary) -> bool:
	service.busy = true
	var result: bool = service.bridge.commit(service.record("crop"), service.feed_inventory("crop"), job)
	service.busy = false
	return result

func _plant(point: Vector2i = Vector2i(48, 30), item: ItemDefinition = SEED) -> void:
	source.add(item, 1)
	assert_true(_commit(service.crop_policy.task("till", point, 5, item)))
	assert_true(_commit(service.crop_policy.task("plant", point, 4, item)))

func test_every_perfect_order_covers_quality_sale_and_never_reduces_base_reward() -> void:
	var prices: ProducePriceCatalog = OrderService.SALE_PRICES
	for entry: OrderDefinition in OrderService.DEFAULT_CATALOG.entries:
		for variant: int in range(3):
			var bag: InventoryComponent = InventoryComponent.new()
			bag.starting_tools = false
			add_child_autofree(bag)
			var wallet: WalletComponent = WalletComponent.new()
			add_child_autofree(wallet)
			wallet.set_balance(0)
			var orders: OrderService = OrderService.new(bag,wallet,func(_entry: OrderDefinition) -> bool: return true)
			var data: Dictionary = OrderSaveSchema.fresh()
			data.initialized = true
			data.next_serial = 2
			data.slots[0] = {"serial":1,"template":String(entry.order_id)}
			assert_true(orders.restore(data))
			var market: int = 0
			for i: int in range(entry.items.size()):
				var silver: int = entry.amounts[i] if variant == 0 else 0 if variant == 1 else int(entry.amounts[i]/2)
				var gold: int = entry.amounts[i]-silver
				bag.add(entry.items[i],silver,1)
				bag.add(entry.items[i],gold,2)
				market += silver*ItemQuality.unit_price(prices.find(entry.items[i].item_id).price,1)+gold*ItemQuality.unit_price(prices.find(entry.items[i].item_id).price,2)
			var quote: Dictionary = orders.quote(1,true)
			assert_true(quote.ok)
			assert_eq(quote.sale_coins,market)
			assert_gte(int(quote.coins)*100,market*110)
			assert_gte(quote.coins,roundi(entry.reward_coins*1.5))
			assert_true(orders.deliver(1,true,quote).ok)
			assert_eq(wallet.balance,quote.coins)

func test_bulk_cooking_processes_an_entire_star_harvest_and_preserves_paid_old_jobs() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var model: ChefCooking = world.cooking
	var old: CookingRecipe = ChefCooking.find("star_apple_tart")
	for i: int in range(old.ingredients.size()):
		bag.add(old.ingredients[i],old.amounts[i])
	assert_eq(model.start("star_apple_tart",1,bag,now),"")
	var snapshot: Dictionary = model.capture(now)
	model.restore(snapshot,now+14401)
	assert_eq(model.collect(bag,now+14401),1)
	assert_eq(bag.count_item(&"star_apple_tart"),1)
	assert_eq(OrderService.SALE_PRICES.find(&"star_apple_tart").price,280)
	var bulk: CookingRecipe = ChefCooking.find("star_apple_tart_batch")
	assert_eq(bulk.amounts,[300,1])
	assert_eq(bulk.cook_seconds,14400.0)
	for i: int in range(bulk.ingredients.size()):
		bag.add(bulk.ingredients[i],bulk.amounts[i])
	assert_eq(model.start(String(bulk.recipe_id),1,bag,now+14401),"")
	assert_eq(model.collect(bag,now+28802),1)
	assert_eq(bag.count_item(&"star_apple_tart_batch"),1)
	assert_eq(OrderService.SALE_PRICES.find(&"star_apple_tart_batch").price,17423)
	assert_gt(17423-150,15000,"Quality harvest cooked in one slot beats Yield harvest plus the same honey sold")

func test_bulk_honey_custard_matches_one_hive_batch_and_unlocks_journal() -> void:
	var recipe: CookingRecipe = ChefCooking.find("hybrid_01_06_custard_batch")
	assert_eq(recipe.amounts,[100,100])
	var bag: InventoryComponent = world.player.selection.inventory
	for i: int in range(recipe.ingredients.size()):
		bag.add(recipe.ingredients[i],recipe.amounts[i])
	assert_eq(world.cooking.start(String(recipe.recipe_id),1,bag,now),"")
	assert_eq(world.cooking.collect(bag,now+14401),1)
	assert_true("hybrid_01_06" in world.honey_garden.discoveries)
	assert_eq(OrderService.SALE_PRICES.find(recipe.output.item_id).price,81200)

func test_worker_stock_and_wages_48h_report_is_reproducible() -> void:
	service.configure_crop(true,false,false)
	source.add(SEED,12)
	var coins: int = world.player.wallet.balance
	service.advance(now+172800)
	var gross: int = 0
	var produce: ItemDefinition = (SEED.crop as CropDefinition).harvest_item
	var output: InventoryComponent = service.output_inventory()
	for tier: int in range(3):
		gross += output.count_item(produce.item_id,tier)*ItemQuality.unit_price(OrderService.SALE_PRICES.find(produce.item_id).price,tier)
	var wages: int = coins-world.player.wallet.balance
	var seed_cost: int = 12*2700
	assert_eq(source.count_item(SEED.item_id),0)
	assert_eq(service.crop_automation.sequence,12)
	assert_gt(gross-seed_cost-wages,0)
	print("BALANCE_WORKER_48H ",JSON.stringify({"gross":gross,"seed_cost":seed_cost,"wages":wages,"net":gross-seed_cost-wages,"plantings":12,"elapsed_hours":48}))
