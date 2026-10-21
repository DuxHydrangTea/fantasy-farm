class_name ShopInteraction
extends Node
var player: FarmPlayer
var active_shop: TradeMenu

func nearest_merchant() -> ShopMerchant:
	var nearest: ShopMerchant
	var distance: float = 48.0 * 48.0
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		var merchant: ShopMerchant = node as ShopMerchant
		if merchant == null or merchant.is_queued_for_deletion() or not merchant.is_visible_in_tree():
			continue
		var squared: float = player.global_position.distance_squared_to(merchant.interaction_position())
		if squared <= distance:
			distance = squared
			nearest = merchant
	return nearest

func try_interact() -> bool:
	if player.selection.is_menu_open():
		return false
	var merchant: ShopMerchant = nearest_merchant()
	var land: LandExpansionComponent = nearest_land_sign()
	if land != null and (merchant == null or player.global_position.distance_squared_to(land.interaction_position()) < player.global_position.distance_squared_to(merchant.interaction_position())):
		return land.open_purchase(player)
	return merchant.open_shop(player) if merchant != null else false

func close_for_load() -> void:
	if is_instance_valid(active_shop):
		active_shop.close(false)

func nearest_land_sign() -> LandExpansionComponent:
	var nearest: LandExpansionComponent
	var distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"land_expansions"):
		var land: LandExpansionComponent = node as LandExpansionComponent
		if land == null or land.is_queued_for_deletion() or not land.can_interact(player):
			continue
		var squared: float = player.global_position.distance_squared_to(land.interaction_position())
		if squared < distance:
			distance = squared
			nearest = land
	return nearest
