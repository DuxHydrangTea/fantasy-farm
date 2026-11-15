class_name PenBoard
extends StaticBody2D
## Bảng tương tác mở giao diện quản lý chuồng cho người chơi trong tầm.

## Chuồng cha được xác định khi node sẵn sàng.
var pen: AnimalPen
## Thế giới chứa chuồng.
var world: FarmWorld
## Sprite dùng để xác định mục tiêu nhấp.
@export var sprite: Sprite2D
## Giao diện quản lý được tạo từ scene.
var menu: PenDashboard

func _ready() -> void:
	add_to_group(&"pen_boards")
	pen = get_parent() as AnimalPen
	world = pen.get_parent() as FarmWorld
	menu = preload("res://scenes/animals/pen_dashboard.tscn").instantiate() as PenDashboard
	menu.board = self
	add_child(menu)

## Mở bảng nếu đúng người chơi, chuồng còn hiển thị và khoảng cách không quá 32.
func open_board(customer: FarmPlayer) -> bool:
	if customer != world.player or not is_instance_valid(pen) or not pen.is_visible_in_tree() or customer.global_position.distance_to(global_position) > 32:
		return false
	return menu.open(null, customer)
