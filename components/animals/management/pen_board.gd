class_name PenBoard
extends StaticBody2D
var pen: AnimalPen
var world: FarmWorld
@export var sprite: Sprite2D
var menu: PenDashboard

func _ready() -> void:
	add_to_group(&"pen_boards")
	pen = get_parent() as AnimalPen
	world = pen.get_parent() as FarmWorld
	menu = preload("res://scenes/animals/pen_dashboard.tscn").instantiate() as PenDashboard
	menu.board = self
	add_child(menu)

func open_board(customer: FarmPlayer) -> bool:
	if customer != world.player or not is_instance_valid(pen) or not pen.is_visible_in_tree() or customer.global_position.distance_to(global_position) > 32:
		return false
	return menu.open(null, customer)
