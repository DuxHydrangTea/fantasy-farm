extends Node2D
## Save-isolated fixture for the skill layout reporter.
func _ready() -> void:
	Language.set_language("vi")
	var world: FarmWorld = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(10000)
	var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	world.player.global_position = merchant.interaction_position() + Vector2(0, 20)
	merchant.open_shop(world.player)
