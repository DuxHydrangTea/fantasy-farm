class_name OrderBoard
extends StaticBody2D
## Bảng đơn hàng tương tác bằng phím, nhấp hoặc cảm ứng qua bộ tương tác chung.

## Thế giới cung cấp túi, ví và nguồn sản phẩm.
var world: FarmWorld
## Dịch vụ quản lý các đơn.
var service: OrderService
## Giao diện bảng đơn.
var menu: OrderUI
## Sprite dùng cho tương tác.
var sprite: Sprite2D
var _availability: OrderAvailability

func _ready() -> void:
	add_to_group(&"order_boards")
	_availability = OrderAvailability.new(world)
	service = OrderService.new(world.player.selection.inventory, world.player.wallet, _availability.allows)
	service.initialize()
	sprite = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = preload("res://assets/Outdoor decoration/Signs.png")
	atlas.region = Rect2(0, 192, 32, 48)
	sprite.texture = atlas
	sprite.position.y = -24
	add_child(sprite)
	# Two posted notes distinguish this from the farmland purchase sign.
	for x: float in [-7.0, 0.0]:
		var paper: Polygon2D = Polygon2D.new()
		paper.polygon = PackedVector2Array([Vector2(x - 3, -32), Vector2(x + 3, -32), Vector2(x + 3, -21), Vector2(x - 3, -21)])
		paper.color = Color("f3deb2")
		add_child(paper)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(24, 6)
	shape.shape = rectangle
	add_child(shape)
	menu = preload("res://scenes/ui/orders.tscn").instantiate() as OrderUI
	menu.board = self
	add_child(menu)

## Mở bảng nếu đúng người chơi, bảng đang hiển thị và trong khoảng 32 đơn vị.
func open_board(customer: FarmPlayer) -> bool:
	if customer != world.player or customer.global_position.distance_to(global_position) > 32 or not is_visible_in_tree():
		return false
	return menu.open(null, customer)
