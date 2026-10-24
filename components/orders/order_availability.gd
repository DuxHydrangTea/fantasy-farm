class_name OrderAvailability
extends RefCounted
## A request is eligible only if this world can grow every requested product.
var world: FarmWorld

func _init(farm: FarmWorld) -> void:
	world = farm

func allows(order: OrderDefinition) -> bool:
	for item: ItemDefinition in order.items:
		if not _has_source(item.item_id):
			return false
	return true

func _has_source(id: StringName) -> bool:
	for node: Node in world.get_tree().get_nodes_in_group(&"shop_merchants"):
		if not world.is_ancestor_of(node) or not node is ShopMerchant:
			continue
		var merchant: ShopMerchant = node as ShopMerchant
		if merchant.catalog == null or not merchant.is_visible_in_tree():
			continue
		for offer: AnimalShopOffer in merchant.catalog.animal_offers:
			if offer != null and offer.is_valid() and offer.animal.production != null and offer.animal.production.production_item != null and offer.animal.production.production_item.item_id == id:
				for child: Node in world.get_children():
					if child is AnimalPen and offer.animal.species in (child as AnimalPen).accepted_species:
						return true
		for offer: ShopOffer in merchant.catalog.offers:
			if offer == null or offer.item == null or offer.item.item_type != ItemDefinition.ItemType.SEED:
				continue
			var source: Resource = offer.item.crop
			if source is CropDefinition:
				var crop: CropDefinition = source as CropDefinition
				if crop.is_valid() and crop.has_valid_harvest() and (crop.harvest_item as ItemDefinition).item_id == id and world.land.state.unlocked_columns > 0:
					return true
			if source is FlowerDefinition and (source as FlowerDefinition).is_valid() and (source as FlowerDefinition).harvest_item.item_id == id:
				for garden: Node in world.get_tree().get_nodes_in_group(&"flower_gardens"):
					if world.is_ancestor_of(garden) and not (garden as FlowerGarden).starter_content_locked and not (garden as FlowerGarden).pots.is_empty():
						return true
	return false
