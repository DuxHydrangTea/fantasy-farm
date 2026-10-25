class_name StarterSupport
extends RefCounted
## One seed per profile when ordinary recovery sources in the bag/farm are gone.
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
var world: FarmWorld

func _init(farm: FarmWorld) -> void:
	world = farm

func quote() -> Dictionary:
	if world.tutorial.capture().support_used:
		return {"ok": false, "error": "Your one-time seed support has already been used."}
	var cheapest: int = 1000001
	for node: Node in world.get_tree().get_nodes_in_group(&"shop_merchants"):
		if not world.is_ancestor_of(node) or not node is ShopMerchant or (node as ShopMerchant).catalog == null:
			continue
		for offer: ShopOffer in (node as ShopMerchant).catalog.offers:
			if offer != null and offer.item != null and offer.item.item_type == ItemDefinition.ItemType.SEED:
				cheapest = mini(cheapest, offer.price)
	if world.player.wallet.balance >= cheapest:
		return {"ok": false, "error": "You can buy seeds at the supply shop."}
	var bag: InventoryComponent = world.player.selection.inventory
	var inventories: Array[InventoryComponent] = [bag]
	if world.storages != null:
		inventories.append(world.storages.inventory("farm_supply_storage"))
		inventories.append(world.storages.inventory("produce_warehouse"))
	for inventory: InventoryComponent in inventories:
		for index: int in range(inventory.slot_count):
			var item: ItemDefinition = inventory.get_slot_item(index)
			if item != null and item.item_type in [ItemDefinition.ItemType.SEED, ItemDefinition.ItemType.PRODUCE]:
				return {"ok": false, "error": "Use your seeds, or sell produce to buy more seeds."}
	if world.farming.has_planted_crops():
		return {"ok": false, "error": "Water and harvest the crops already in your field."}
	if bag.capacity_for(SEED) < 1:
		return {"ok": false, "error": "Make room in your bag before receiving a seed."}
	return {"ok": true}

func claim() -> Dictionary:
	var checked: Dictionary = quote()
	if not checked.ok:
		return checked
	if not world.tutorial.grant_support(world.player.selection.inventory, SEED):
		return {"ok": false, "error": "Your inventory has changed."}
	return {"ok": true}
