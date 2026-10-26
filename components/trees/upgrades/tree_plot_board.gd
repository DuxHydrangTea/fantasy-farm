class_name TreePlotBoard
extends StaticBody2D
var world: FarmWorld
var kind: TreeDefinition.Kind
var sprite: Sprite2D
var menu: TreePlotMenu

func _ready() -> void:
	add_to_group(&"tree_plot_boards")
	sprite = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = preload("res://assets/Outdoor decoration/Signs.png")
	atlas.region = Rect2(0, 192, 32, 48)
	sprite.texture = atlas
	sprite.position.y = -24
	add_child(sprite)
	var emblem: Polygon2D = Polygon2D.new()
	emblem.polygon = PackedVector2Array([Vector2(-7,-31), Vector2(0,-38), Vector2(7,-31), Vector2(4,-24), Vector2(-4,-24)])
	emblem.color = Color("dc8a54") if kind == TreeDefinition.Kind.FRUIT else Color("64a76b")
	add_child(emblem)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(24, 6)
	shape.shape = rectangle
	add_child(shape)
	menu = TreePlotMenu.new()
	menu.board = self
	add_child(menu)

func open_board(customer: FarmPlayer) -> bool:
	if customer != world.player or not is_visible_in_tree() or customer.global_position.distance_to(global_position) > 32:
		return false
	return menu.open(null, customer)
