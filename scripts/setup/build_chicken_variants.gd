extends SceneTree
## One-time deterministic resource authoring, using ResourceSaver for links/UIDs.
func _initialize() -> void:
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/setup/animal_variant_names.json"))
	var base: AnimalDefinition = load("res://animals/definitions/chicken.tres") as AnimalDefinition
	var offers: Array[AnimalShopOffer] = []
	for index: int in range(2, 19):
		var id: String = "chicken_%02d" % index
		var production: AnimalProductionDefinition = base.production.duplicate() as AnimalProductionDefinition
		production.production_amount = 100 + 25 * (index - 1)
		var production_path: String = "res://animals/productions/%s_egg_production.tres" % id
		assert(ResourceSaver.save(production, production_path) == OK)
		production = load(production_path) as AnimalProductionDefinition
		var definition: AnimalDefinition = base.duplicate() as AnimalDefinition
		definition.animal_id = StringName(id)
		assert(names.has(id))
		definition.display_name = String(names[id].en)
		var frames_path: String = "res://sprite_frames/animals/%s_frames.tres" % id
		definition.adult_frames = load(frames_path) as SpriteFrames
		definition.production = production
		var path: String = "res://animals/definitions/%s.tres" % id
		assert(ResourceSaver.save(definition, path) == OK)
		var offer: AnimalShopOffer = AnimalShopOffer.new()
		offer.animal = load(path) as AnimalDefinition
		offer.price = 16000 + 4000 * (index - 1)
		var offer_path: String = "res://resources/shops/animals/%s.tres" % id
		assert(ResourceSaver.save(offer, offer_path) == OK)
		offers.append(load(offer_path) as AnimalShopOffer)
	for path: String in ["res://resources/shops/farm_supply.tres", "res://resources/shops/pet_shop.tres"]:
		var stock: ShopCatalog = load(path) as ShopCatalog
		var rows: Array[AnimalShopOffer] = []
		for offer: AnimalShopOffer in stock.animal_offers:
			if not String(offer.animal.animal_id).begins_with("chicken_"): rows.append(offer)
		rows.append_array(offers)
		stock.animal_offers = rows
		assert(ResourceSaver.save(stock, path) == OK)
	print("CHICKEN_VARIANTS: 18 choices; 16000..84000 coins; 100..525 eggs per 900 seconds")
	quit()
