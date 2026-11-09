extends "res://tests/integration/test_chicken_variants.gd"
## Exercise the same trade/persistence pipeline for every other production species.
const TIERS: Dictionary = {"cow": 9, "sheep": 9, "pig": 16, "duck": 5, "goose": 6}

func livestock_offer(id: String) -> AnimalShopOffer:
	for offer: AnimalShopOffer in STOCK.animal_offers:
		if String(offer.animal.animal_id) == id:
			return offer
	return null

func test_all_livestock_tiers_keep_species_cycles_and_proportional_value() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var general: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	assert_eq(STOCK.animal_offers.size(), 64)
	for species: String in TIERS:
		var base: AnimalShopOffer = livestock_offer(species)
		var frames: Dictionary = {base.animal.adult_frames: true}
		for index: int in range(2, int(TIERS[species]) + 1):
			var id: String = "%s_%02d" % [species, index]
			var offer: AnimalShopOffer = livestock_offer(id)
			assert_not_null(offer, id)
			assert_true(offer.is_valid(), id)
			assert_true(general.animal_offers.has(offer), id)
			assert_eq(catalog.animals[id], offer.animal)
			assert_eq(offer.animal.species, base.animal.species)
			assert_false(frames.has(offer.animal.adult_frames), id)
			frames[offer.animal.adult_frames] = true
			assert_eq(offer.price * 100, base.price * offer.animal.production.production_amount)
			assert_eq(offer.animal.production.production_amount, 100 + 25 * (index - 1))
			assert_eq(offer.animal.production.production_seconds, base.animal.production.production_seconds)
			var production: AnimalProductionComponent = AnimalProductionComponent.new()
			production.configure(offer.animal.production)
			assert_eq(production.advance(base.animal.production.production_seconds - 1.0), 0)
			assert_eq(production.advance(1.0), offer.animal.production.production_amount)
			production.free()

func test_premium_livestock_purchase_produce_save_load_and_resale() -> void:
	for species: String in TIERS:
		var offer: AnimalShopOffer = livestock_offer("%s_%02d" % [species, TIERS[species]])
		# The inherited fixture disables world processing, including pond navigation.
		(world.get_node("PondPen") as PondPen).rebuild_navigation()
		world.player.wallet.set_balance(2000000)
		var bought: Dictionary = service.buy(offer, 1)
		assert_true(bought.ok, "%s: %s" % [species, bought.get("error", "")])
		if not bought.ok:
			continue
		var animal: AnimalActor = bought.animals[0]
		var id: String = String(animal.persistent_id)
		assert_eq(animal.sprite.sprite_frames, offer.animal.adult_frames)
		assert_eq(world.player.wallet.balance, 2000000 - offer.price)
		assert_eq(service.quote_sell(animal).total, offer.resale_price(false))
		animal.growth.configure(animal.definition.maturity_seconds, animal.definition.maturity_seconds, animal.definition.lifespan_seconds)
		# Feed eligible time directly: this checks output persistence without starvation.
		animal.production.advance(offer.animal.production.production_seconds)
		var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
		var saved: Dictionary = adapter.capture("livestock_test", 1, clock[0])
		assert_true(SaveSchema.validate(saved, adapter.catalog).ok, species)
		assert_true(adapter.restore(saved, clock[0]).ok, species)
		animal = world.workers.bridge.animal_for(id)
		assert_not_null(animal, species)
		assert_eq(animal.definition, offer.animal)
		assert_eq(animal.sprite.sprite_frames, offer.animal.adult_frames)
		var output: int = animal.production.stored_amount
		if animal.product_pickup() != null:
			output += animal.product_pickup().amount
		assert_eq(output, offer.animal.production.production_amount)
		assert_eq(service.quote_sell(animal).total, offer.resale_price(true))
		assert_true(service.sell(animal).ok, species)
		assert_eq(world.player.wallet.balance, 2000000 - offer.price + offer.resale_price(true))

func test_old_livestock_skins_remain_cosmetic_after_save_load() -> void:
	for species: String in TIERS:
		(world.get_node("PondPen") as PondPen).rebuild_navigation()
		var base: AnimalShopOffer = livestock_offer(species)
		var premium: AnimalShopOffer = livestock_offer("%s_%02d" % [species, TIERS[species]])
		var bought: Dictionary = service.buy(base, 1)
		assert_true(bought.ok, species)
		if not bought.ok:
			continue
		var animal: AnimalActor = bought.animals[0]
		var id: String = String(animal.persistent_id)
		animal.skin_frames = premium.animal.adult_frames
		var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
		var saved: Dictionary = adapter.capture("old_livestock", 1, clock[0])
		assert_true(adapter.restore(saved, clock[0]).ok, species)
		animal = world.workers.bridge.animal_for(id)
		assert_eq(animal.definition, base.animal)
		assert_eq(animal.skin_frames, premium.animal.adult_frames)
		assert_eq(animal.production.definition.production_amount, 100)
		assert_eq(service.quote_sell(animal).total, base.resale_price(false))
		assert_true(service.sell(animal).ok)
