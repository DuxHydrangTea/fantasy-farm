extends Node2D
## F6 sandbox: preview-only coins/land, never binds or writes a personal profile.
var world: FarmWorld

func _ready() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.player.wallet.set_balance(10000000)
	world.land.state.restore_columns(13, 4)
	world.tool_upgrades.profile_ready = true
	world.weather.set_debug_hour(12)
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		if world.is_ancestor_of(node):
			var merchant: ShopMerchant = node as ShopMerchant
			world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
			merchant.open_shop(world.player)
			merchant.shop_ui.show_category(ShopUI.UPGRADES)
			break
