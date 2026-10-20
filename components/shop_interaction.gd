class_name ShopInteraction
extends Node
var player: FarmPlayer
var active_shop: ShopUI

func nearest_merchant() -> ShopMerchant:
	var nearest: ShopMerchant
	var distance: float = 48.0 * 48.0
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		var merchant: ShopMerchant = node as ShopMerchant
		if merchant == null or not merchant.is_visible_in_tree():
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
	if merchant == null:
		return false
	return merchant.open_shop(player)

func close_for_load() -> void:
	if is_instance_valid(active_shop):
		active_shop.close(false)
