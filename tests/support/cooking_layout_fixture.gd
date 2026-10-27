extends Node2D
## Farm stays a child so this preview never binds the personal save adapter.
var world: FarmWorld
var menu: CookingMenu
var clock: Array[float] = [1000000.0]

func _ready() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	clock[0] = world.farming.time_manager.now()
	world.farming.time_manager.clock_source = func() -> float: return clock[0]
	world.cooking.restore(ChefCooking.fresh(), clock[0])
	world.player.wallet.set_balance(12500)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(preload("res://items/animal_produces/chicken_egg.tres"), 12)
	world.cooking.start("fried_egg", 3, bag, clock[0], world.player.wallet)
	clock[0] += ChefCooking.RECIPES[0].cook_seconds * 1.4
	var chef: ChefMerchant = world.get_node("Chef") as ChefMerchant
	world.player.global_position = chef.interaction_position() + Vector2(0, 20)
	menu = chef.menu as CookingMenu
	chef.open_shop(world.player)

func _exit_tree() -> void:
	TimeManager.clock_source = Time.get_unix_time_from_system
