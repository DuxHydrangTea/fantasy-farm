extends GutTest
var farm: Node2D
var pen: AnimalPen
var clock: FarmClock
var timestamp: float = 1000.0
var wallet: WalletComponent
var catalog: ShopCatalog
var offer: AnimalShopOffer
var service: AnimalTradeService

func before_each() -> void:
	timestamp = 1000.0
	farm = Node2D.new()
	add_child_autofree(farm)
	pen = AnimalPen.new()
	pen.bounds = Rect2(0, 0, 240, 160)
	pen.accepted_species = [AnimalTypes.Species.CHICKEN]
	pen.capacity = 3
	farm.add_child(pen)
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	wallet = WalletComponent.new()
	add_child_autofree(wallet)
	catalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	offer = catalog.animal_offers[0]
	service = AnimalTradeService.new(catalog, wallet, farm, clock)
	await wait_physics_frames(2)

func test_catalog_has_seven_species_and_resale_never_exceeds_purchase() -> void:
	assert_eq(catalog.animal_offers.size(), 7)
	var ids: Dictionary = {}
	for entry: AnimalShopOffer in catalog.animal_offers:
		assert_true(entry.is_valid())
		assert_not_null(entry.icon())
		assert_false(ids.has(entry.animal.animal_id))
		ids[entry.animal.animal_id] = true
		assert_lt(entry.resale_price(false), entry.resale_price(true))
		assert_lt(entry.resale_price(true), entry.price)

func test_batch_purchase_places_distinct_newborns_and_publishes_complete_transaction() -> void:
	var observations: Array[int] = []
	var reentry: Array[bool] = []
	wallet.changed.connect(func(_balance: int) -> void:
		observations.append(service.owned_animals().size())
		reentry.append(bool(service.buy(offer, 1).ok)))
	var result: Dictionary = service.buy(offer, 2)
	assert_true(result.ok)
	assert_eq(wallet.balance, 680)
	assert_eq(observations, [2])
	assert_eq(reentry, [false])
	var actors: Array[AnimalActor] = service.owned_animals()
	assert_ne(actors[0].position, actors[1].position)
	assert_ne(actors[0].persistent_id, actors[1].persistent_id)
	for actor: AnimalActor in actors:
		assert_eq(actor.pen, pen)
		assert_eq(actor.growth.age_seconds, 0.0)
		assert_eq(actor.growth.maturity_seconds, 86400.0)
		assert_eq(actor.growth.lifespan_seconds, 1209600.0)
		assert_eq(actor.needs.time_manager, clock)
		assert_true(pen.contains_world(actor.global_position, actor.wander.margin))
	# A second same-frame purchase must also avoid the just-created actors.
	assert_true(service.buy(offer, 1).ok)
	assert_eq(service.owned_animals().size(), 3)
	assert_eq(wallet.balance, 520)

func test_full_missing_or_blocked_pen_and_invalid_request_never_spend_coins() -> void:
	pen.capacity = 1
	assert_false(service.buy(offer, 2).ok)
	pen.accepted_species.clear()
	assert_false(service.buy(offer, 1).ok)
	pen.accepted_species = [AnimalTypes.Species.CHICKEN]
	wallet.set_balance(159)
	assert_false(service.buy(offer, 1).ok)
	wallet.set_balance(1000)
	for amount: int in [-1, 0, 100]:
		assert_false(service.buy(offer, amount).ok)
	assert_false(service.buy(offer.duplicate() as AnimalShopOffer, 1).ok)
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(500, 500)
	collision.shape = shape
	wall.add_child(collision)
	farm.add_child(wall)
	await wait_physics_frames(2)
	assert_false(service.buy(offer, 1).ok)
	assert_eq(wallet.balance, 1000)
	assert_eq(service.owned_animals().size(), 0)

func test_sell_once_credits_young_price_preserves_output_and_cannot_reenter() -> void:
	var actor: AnimalActor = service.buy(offer, 1).animals[0]
	actor.production.restore_state(0.0, 2)
	watch_signals(actor)
	var reentry: Array[bool] = []
	wallet.changed.connect(func(_balance: int) -> void:
		assert_eq(service.owned_animals().size(), 0)
		reentry.append(bool(service.sell(actor).ok)))
	assert_true(service.sell(actor).ok)
	assert_eq(wallet.balance, 920)
	assert_eq(reentry, [false])
	assert_true(actor.is_queued_for_deletion())
	assert_false(actor.is_dead(), "Selling a living actor must not report death")
	assert_signal_not_emitted(actor, "died")
	var pile: ItemPickup = actor.product_pickup()
	assert_eq(pile.amount, 2)
	assert_false(service.sell(actor).ok)
	await wait_physics_frames(2)
	assert_true(is_instance_valid(pile))

func test_adult_price_foreign_actor_and_wallet_overflow_are_revalidated() -> void:
	var actor: AnimalActor = service.buy(offer, 1).animals[0]
	actor.growth.configure(86400.0, 86400.0, 1209600.0)
	assert_eq(int(service.quote_sell(actor).total), 120)
	var foreign: AnimalTradeService = AnimalTradeService.new(catalog, wallet, self, clock)
	assert_false(foreign.sell(actor).ok)
	wallet.set_balance(WalletComponent.MAX_COINS)
	assert_false(service.sell(actor).ok)
	assert_false(actor.is_queued_for_deletion())
	wallet.set_balance(0)
	assert_true(service.sell(actor).ok)
	assert_eq(wallet.balance, 120)

func test_clock_sync_at_checkout_prevents_selling_after_lifetime_expires() -> void:
	var actor: AnimalActor = service.buy(offer, 1).animals[0]
	actor.growth.configure(86400.0, 1209599.0, 1209600.0)
	timestamp += 2.0
	assert_false(service.sell(actor).ok)
	assert_true(actor.is_dead())
	assert_eq(wallet.balance, 840)
