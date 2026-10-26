extends Node

const IDS: Array[String] = ["autumn_maple", "blue_conifer", "brown_palm", "evergreen_spruce", "flowering_cactus", "golden_aspen", "golden_birch", "magic_blue", "orange_oak", "palm", "pink_blossom", "purple_blossom", "red_maple", "willow"]
const CATALOG: String = "res://resources/shops/farm_supply.tres"

func _ready() -> void:
	var catalog: ShopCatalog = load(CATALOG) as ShopCatalog
	var before: int = catalog.offers.size()
	if OS.get_cmdline_user_args().has("install"):
		var insertion: int = before
		for index: int in range(before):
			if catalog.offers[index].item.item_id == &"axe":
				insertion = index
				break
		for id: String in IDS:
			var item: ItemDefinition = load("res://items/trees/%s_sapling.tres" % id) as ItemDefinition
			var present: bool = false
			for existing: ShopOffer in catalog.offers:
				if existing.item.item_id == item.item_id:
					present = true
			if present:
				continue
			var offer: ShopOffer = ShopOffer.new()
			offer.item = item
			offer.price = 25000
			offer.category = ShopOffer.Category.FEED
			catalog.offers.insert(insertion, offer)
			insertion += 1
		assert(catalog.offers.size() == before + 14)
		assert(ResourceSaver.save(catalog, CATALOG) == OK)
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	add_child(bag)
	var wallet: WalletComponent = WalletComponent.new()
	add_child(wallet)
	wallet.set_balance(1000000)
	var service: ShopService = ShopService.new(catalog, wallet, bag)
	var seen: Dictionary = {}
	var timber: int = 0
	var fruit: int = 0
	var purchases: int = 0
	for offer: ShopOffer in catalog.offers:
		assert(not seen.has(offer.item.item_id), String(offer.item.item_id))
		seen[offer.item.item_id] = true
		if offer.item.crop is TreeDefinition:
			if (offer.item.crop as TreeDefinition).kind == TreeDefinition.Kind.TIMBER:
				timber += 1
			else:
				fruit += 1
		for id: String in IDS:
			if offer.item.item_id != StringName(id + "_sapling"):
				continue
			assert(offer.item.icon != null)
			assert(offer.item.icon.resource_path == "res://assets/Icons/tree_saplings/%s_sapling.png" % id)
			assert(offer.category == ShopOffer.Category.FEED and offer.price == 25000)
			assert(service.buy(offer, 1).ok)
			assert(bag.count_item(offer.item.item_id) == 1)
			purchases += 1
	assert(timber == 17 and fruit == 4 and purchases == 14)
	assert(wallet.balance == 650000)
	print("SHOP_TREE_ICONS_VERIFIED " + JSON.stringify({"timber_species":timber,"fruit_species":fruit,"new_icons":purchases,"price":25000,"purchase_checks":14,"duplicates":0}))
	get_tree().quit(0)
