extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const STOCK: ShopCatalog = preload("res://resources/shops/pet_shop.tres")
var world: FarmWorld
var service: AnimalTradeService
var old_clock: Callable
var old_floor: float
var clock: Array[float]

func before_each() -> void:
	old_clock = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	clock = [1793500000.0]
	var manual: Array[float] = clock
	TimeManager._last_timestamp = clock[0]
	TimeManager.clock_source = func() -> float: return manual[0]
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.player.wallet.set_balance(2000000)
	world.tool_upgrades.profile_ready = true
	service = AnimalTradeService.new(STOCK, world.player.wallet, world, TimeManager)
	await wait_physics_frames(2)

func after_each() -> void:
	TimeManager.clock_source = old_clock
	TimeManager._last_timestamp = old_floor

func offer_for(index: int) -> AnimalShopOffer:
	var id: String = "chicken" if index == 1 else "chicken_%02d" % index
	for offer: AnimalShopOffer in STOCK.animal_offers:
		if String(offer.animal.animal_id) == id: return offer
	return null

func test_all_eighteen_skins_are_distinct_buyable_definitions_with_linear_yield() -> void:
	var resources: SaveCatalog = SaveCatalog.new()
	var general: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	assert_eq(STOCK.animal_offers.size(), 24)
	var frames: Dictionary = {}
	for index: int in range(1, 19):
		var offer: AnimalShopOffer = offer_for(index)
		assert_not_null(offer)
		assert_true(general.animal_offers.has(offer))
		assert_true(offer.is_valid())
		assert_true(resources.animals.has(String(offer.animal.animal_id)))
		assert_eq(offer.animal.adult_frames.resource_path, "res://sprite_frames/animals/chicken_%02d_frames.tres" % index)
		assert_false(frames.has(offer.animal.adult_frames))
		frames[offer.animal.adult_frames] = true
		assert_eq(offer.price, 16000 + 4000 * (index - 1))
		assert_eq(offer.animal.production.production_amount, 100 + 25 * (index - 1))
		assert_eq(offer.animal.production.production_seconds, 900.0)
		assert_eq(offer.price * 100, 16000 * offer.animal.production.production_amount)
		var production: AnimalProductionComponent = AnimalProductionComponent.new()
		production.configure(offer.animal.production)
		assert_eq(production.advance(899.0), 0)
		assert_eq(production.advance(1.0), offer.animal.production.production_amount)
		assert_eq(production.advance(1800.0), offer.animal.production.production_amount * 2)
		production.free()

func test_buy_resale_and_roundtrip_keep_variant_skin_price_and_stock() -> void:
	var premium: AnimalShopOffer = offer_for(18)
	var bought: Dictionary = service.buy(premium, 1)
	assert_true(bought.ok)
	var animal: AnimalActor = bought.animals[0]
	var id: String = String(animal.persistent_id)
	assert_eq(animal.sprite.sprite_frames, premium.animal.adult_frames)
	assert_eq(world.player.wallet.balance, 2000000 - 84000)
	assert_eq(service.quote_sell(animal).total, 42000)
	animal.growth.configure(animal.definition.maturity_seconds, animal.definition.maturity_seconds, animal.definition.lifespan_seconds)
	assert_eq(service.quote_sell(animal).total, 63000)
	clock[0] += 900
	animal.needs.update_at(clock[0])
	assert_not_null(animal.product_pickup())
	assert_eq(animal.product_pickup().amount, 525)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("chicken_test", 1, clock[0])
	assert_true(SaveSchema.validate(saved, adapter.catalog).ok)
	assert_eq(saved.animals[0].animal, "chicken_18")
	assert_true(adapter.restore(saved, clock[0]).ok)
	animal = world.workers.bridge.animal_for(id)
	assert_not_null(animal)
	assert_eq(animal.definition.animal_id, &"chicken_18")
	assert_eq(animal.sprite.sprite_frames, premium.animal.adult_frames)
	assert_eq(animal.product_pickup().amount, 525)
	assert_eq(service.quote_sell(animal).total, 63000)
	assert_true(service.sell(animal).ok)
	assert_eq(world.player.wallet.balance, 2000000 - 84000 + 63000)
	assert_false(service.sell(animal).ok)

func test_old_chicken_skin_is_preserved_without_granting_premium_yield() -> void:
	var bought: Dictionary = service.buy(offer_for(1), 1)
	assert_true(bought.ok)
	var animal: AnimalActor = bought.animals[0]
	animal.skin_frames = load("res://sprite_frames/animals/chicken_18_frames.tres") as SpriteFrames
	animal._apply_stage_visuals()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("chicken_test", 1, clock[0])
	assert_true(adapter.restore(saved, clock[0]).ok)
	animal = world.workers.bridge.animal_for(String(saved.animals[0].id))
	assert_eq(animal.definition.animal_id, &"chicken")
	assert_eq(animal.skin_frames.resource_path, "res://sprite_frames/animals/chicken_18_frames.tres")
	assert_eq(animal.production.definition.production_amount, 100)
	assert_eq(service.quote_sell(animal).total, 8000)

func test_insufficient_coins_and_pen_capacity_keep_wallet_and_population() -> void:
	world.player.wallet.set_balance(83999)
	assert_false(service.buy(offer_for(18), 1).ok)
	assert_eq(service.owned_animals().size(), 0)
	assert_eq(world.player.wallet.balance, 83999)
	world.player.wallet.set_balance(2000000)
	assert_false(service.buy(offer_for(18), 6).ok)
	assert_eq(service.owned_animals().size(), 0)
	assert_eq(world.player.wallet.balance, 2000000)
