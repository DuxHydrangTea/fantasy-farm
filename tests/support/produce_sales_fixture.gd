extends Node2D
## Isolated farm child: previews do not attach the personal-save adapter.
var world: FarmWorld
var menu: ProduceSalesUI

func _ready() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(12500)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(preload("res://items/harvest_produces/carrot_produces.tres"), 24)
	bag.add(preload("res://items/animal_produces/chicken_egg.tres"), 12)
	bag.add(preload("res://items/animal_produces/cow_milk.tres"), 8)
	bag.add(preload("res://items/cooked/fried_egg.tres"), 3)
	bag.add(preload("res://items/harvest_produces/carrot_produces.tres"), 5, 1)
	bag.add(preload("res://items/harvest_produces/carrot_produces.tres"), 2, 2)
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	world.player.global_position = buyer.interaction_position() + Vector2(0, 20)
	menu = buyer.menu as ProduceSalesUI
	buyer.open_shop(world.player)
	menu.quantity.value = 10
