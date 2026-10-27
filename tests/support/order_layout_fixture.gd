extends Node2D
## Farm is a child; no personal save adapter is attached to this QA scene.
var world: FarmWorld
var menu: OrderUI
@export var show_confirmation: bool = false

func _ready() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.player.wallet.set_balance(12500)
	var service: OrderService = world.orders.service
	var serial: int = int(service.capture().slots[0].serial)
	var entry: OrderDefinition = service.definition(serial)
	for index: int in range(entry.items.size()):
		service.inventory.add(entry.items[index], entry.amounts[index] + 8, 0)
		service.inventory.add(entry.items[index], entry.amounts[index] + 2, 1)
	world.player.global_position = world.orders.global_position + Vector2(0, 24)
	menu = world.orders.menu
	world.orders.open_board(world.player)
	if show_confirmation:
		menu._request("perfect")
