extends SceneTree
## Mirrors chicken tiers: each skin adds 25% of base price and base yield.
const SPECIES: Dictionary = {"cow": 9, "sheep": 9, "pig": 16, "duck": 5, "goose": 6}

func _initialize() -> void:
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/setup/animal_variant_names.json"))
	var offers: Array[AnimalShopOffer] = []
	for species: String in SPECIES:
		var base_path: String = "res://animals/definitions/%s.tres" % species
		var base_offer_path: String = "res://resources/shops/animals/%s.tres" % species
		var base: AnimalDefinition = load(base_path) as AnimalDefinition
		var base_offer: AnimalShopOffer = load(base_offer_path) as AnimalShopOffer
		for index: int in range(2, int(SPECIES[species]) + 1):
			var id: String = "%s_%02d" % [species, index]
			var production: AnimalProductionDefinition = base.production.duplicate() as AnimalProductionDefinition
			production.production_amount = base.production.production_amount + (base.production.production_amount / 4) * (index - 1)
			var production_path: String = "res://animals/productions/%s_production.tres" % id
			assert(ResourceSaver.save(production, production_path) == OK)
			var definition: AnimalDefinition = base.duplicate() as AnimalDefinition
			definition.animal_id = StringName(id)
			assert(names.has(id))
			definition.display_name = String(names[id].en)
			var skin: String = "duck_in_a_hat" if species == "duck" and index == 5 else id
			var frames_path: String = "res://sprite_frames/animals/%s_frames.tres" % skin
			definition.adult_frames = load(frames_path) as SpriteFrames
			definition.production = load(production_path) as AnimalProductionDefinition
			assert(definition.is_valid())
			var path: String = "res://animals/definitions/%s.tres" % id
			assert(ResourceSaver.save(definition, path) == OK)
			var offer: AnimalShopOffer = AnimalShopOffer.new()
			offer.animal = load(path) as AnimalDefinition
			offer.price = base_offer.price + (base_offer.price / 4) * (index - 1)
			var offer_path: String = "res://resources/shops/animals/%s.tres" % id
			assert(ResourceSaver.save(offer, offer_path) == OK)
			offers.append(load(offer_path) as AnimalShopOffer)
	for path: String in ["res://resources/shops/farm_supply.tres", "res://resources/shops/pet_shop.tres"]:
		var stock: ShopCatalog = load(path) as ShopCatalog
		var rows: Array[AnimalShopOffer] = []
		for offer: AnimalShopOffer in stock.animal_offers:
			if not offers.any(func(entry: AnimalShopOffer) -> bool: return entry.animal.animal_id == offer.animal.animal_id):
				rows.append(offer)
		rows.append_array(offers)
		stock.animal_offers = rows
		assert(ResourceSaver.save(stock, path) == OK)
	print("LIVESTOCK_VARIANTS: added 40 tiers across cow, sheep, pig, duck and goose")
	quit()
