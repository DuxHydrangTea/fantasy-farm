extends Node2D
## Pixel tool animation; presentation never commits work or spends supplies.
var kind: String = ""
var elapsed: float = 0.0
var direction: Vector2 = Vector2.RIGHT

func show_action(action: String, facing: Vector2) -> void:
	kind = action
	direction = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	visible = not kind.is_empty()

func _process(delta: float) -> void:
	if visible:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	if kind.is_empty():
		return
	var hand: Vector2 = Vector2(0, -9) + direction * (5.0 + sin(elapsed * 8.0))
	draw_set_transform(hand, direction.angle())
	if kind == "cure_animal":
		draw_rect(Rect2(0, -2, 7, 4), Color("e6eef3"))
		draw_rect(Rect2(2, -1, 3, 2), Color("ed6262"))
		draw_line(Vector2(7, 0), Vector2(12, 0), Color("a4bbc9"), 1)
		draw_line(Vector2(-2, -3), Vector2(-2, 3), Color("566974"), 1)
	else:
		draw_rect(Rect2(-3, -1, 6, 8), Color("6b9b55") if kind == "treat_weeds" else Color("c48c47"))
		draw_rect(Rect2(-1, -4, 5, 3), Color("e2e5ca"))
		draw_line(Vector2(3, -3), Vector2(8, -3), Color("526d6a"), 2)
		for index: int in range(5):
			var phase: float = fposmod(elapsed * 2.0 + index * 0.2, 1.0)
			draw_circle(Vector2(8 + phase * 13, -3 + sin(index * 2.0) * phase * 5), 0.8, Color(0.78, 0.94, 0.87, 1.0 - phase))
