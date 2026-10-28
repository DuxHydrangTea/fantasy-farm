extends Node

func _ready() -> void:
	_run.call_deferred()

func _save(resource: Resource, path: String) -> void:
	assert(ResourceSaver.save(resource, path) == OK, path)

func _building(path: String, texture_path: String, sprite_y: float, width: float) -> void:
	var building: StaticBody2D = StaticBody2D.new()
	building.name = "ShopBuilding"
	building.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(texture_path) as Texture2D
	sprite.position.y = sprite_y
	building.add_child(sprite)
	sprite.owner = building
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(width, 20)
	collision.shape = shape
	collision.position.y = -10
	building.add_child(collision)
	collision.owner = building
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(building) == OK)
	_save(scene, path)
	building.free()

func _merchant(path: String, title: String, catalog_path: String, frames_path: String) -> void:
	var npc: ShopMerchant = load("res://scenes/characters/shop_merchant.tscn").instantiate() as ShopMerchant
	npc.name = title
	npc.catalog = load(catalog_path) as ShopCatalog
	(npc.get_node("Sprite") as AnimatedSprite2D).sprite_frames = load(frames_path) as SpriteFrames
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(npc) == OK)
	_save(scene, path)
	npc.free()

func _run() -> void:
	var source: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var seeds: ShopCatalog = ShopCatalog.new()
	seeds.display_name = "Seed and flower shop"
	seeds.category_ids = [0, 2, 1]
	var pets: ShopCatalog = ShopCatalog.new()
	pets.display_name = "Animal shop"
	pets.category_ids = [3, 4, 1]
	pets.animal_offers.assign(source.animal_offers)
	var smith: ShopCatalog = ShopCatalog.new()
	smith.display_name = "Blacksmith"
	smith.category_ids = [6, 5, 1]
	for original: ShopOffer in source.offers:
		var offer: ShopOffer = original.duplicate() as ShopOffer
		if offer.item.item_type in [ItemDefinition.ItemType.TOOL, ItemDefinition.ItemType.HOE]:
			offer.category = ShopOffer.Category.TOOLS
			smith.offers.append(offer)
		elif offer.item.item_id == WoodMarket.ITEM:
			smith.offers.append(offer)
		elif offer.item.item_type == ItemDefinition.ItemType.FEED or offer.item.item_id == &"animal_tonic":
			pets.offers.append(offer)
		else:
			seeds.offers.append(offer)
	for path: String in ["res://items/tools/hoe.tres", "res://items/tools/watering_can.tres"]:
		var offer: ShopOffer = ShopOffer.new()
		offer.item = load(path) as ItemDefinition
		offer.price = 250
		offer.category = ShopOffer.Category.TOOLS
		smith.offers.append(offer)
	_save(seeds, "res://resources/shops/seed_flower_shop.tres")
	_save(pets, "res://resources/shops/pet_shop.tres")
	_save(smith, "res://resources/shops/blacksmith.tres")
	DirAccess.make_dir_recursive_absolute("res://scenes/buildings/shops")
	_building("res://scenes/buildings/shops/seed_flower_shop.tscn", "res://assets/Buildings/Shops/crop_flower_shop_red.png", -50, 106)
	_building("res://scenes/buildings/shops/pet_shop.tscn", "res://assets/Buildings/pet_shop_pigpen.png", -60, 106)
	_merchant("res://scenes/characters/seed_flower_merchant.tscn", "LaiBuon", "res://resources/shops/seed_flower_shop.tres", "res://sprite_frames/character/bartender_katy_frames.tres")
	_merchant("res://scenes/characters/pet_merchant.tscn", "PetMerchant", "res://resources/shops/pet_shop.tres", "res://sprite_frames/character/lumberjack_jack_frames.tres")
	_merchant("res://scenes/characters/blacksmith_merchant.tscn", "BlacksmithMerchant", "res://resources/shops/blacksmith.tres", "res://sprite_frames/character/miner_mike_frames.tres")
	print(JSON.stringify({"seeds":seeds.offers.size(), "pet_supplies":pets.offers.size(), "animals":pets.animal_offers.size(), "smith":smith.offers.size()}))
	get_tree().quit()
