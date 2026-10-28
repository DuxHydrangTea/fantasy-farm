extends "res://debug_saves/shop_split/build.gd"

func _run() -> void:
	var stock: ShopCatalog = load("res://resources/shops/seed_flower_shop.tres") as ShopCatalog
	var flowers: ShopCatalog = ShopCatalog.new()
	flowers.display_name = "Flower shop"
	flowers.category_ids = [ShopOffer.Category.FLOWER]
	var remaining: Array[ShopOffer] = []
	for offer: ShopOffer in stock.offers:
		if offer.category == ShopOffer.Category.FLOWER:
			flowers.offers.append(offer.duplicate() as ShopOffer)
		else:
			remaining.append(offer)
	assert(flowers.offers.size() == 30)
	stock.offers = remaining
	stock.display_name = "Seed shop"
	stock.category_ids = [ShopOffer.Category.CROP, ShopOffer.Category.FEED]
	_save(stock, "res://resources/shops/seed_flower_shop.tres")
	_save(flowers, "res://resources/shops/flower_shop.tres")
	_building("res://scenes/buildings/shops/flower_shop.tscn", "res://assets/Buildings/Extracted/VillageSet/flower_shop.png", -86, 100)
	_merchant("res://scenes/characters/flower_merchant.tscn", "FlowerMerchant", "res://resources/shops/flower_shop.tres", "res://sprite_frames/character/bartender_bruno_frames.tres")
	print(JSON.stringify({"seed_shop":stock.offers.size(), "flower_shop":flowers.offers.size()}))
	get_tree().quit()
