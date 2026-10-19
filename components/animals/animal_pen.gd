@tool
extends Node2D
@export var persistent_id: StringName
## Rect in this node's local space, shared by any number of animals.
@export var bounds: Rect2 = Rect2(0, 0, 384, 256):
	set(value):
		bounds = value.abs()
		queue_redraw()

func allowed_bounds(margin: float = 0.0) -> Rect2:
	var inset: Vector2 = Vector2.ONE * maxf(0.0, margin)
	inset = inset.min(bounds.size * 0.5)
	return Rect2(bounds.position + inset, bounds.size - inset * 2.0)

func contains_world(point: Vector2, margin: float = 0.0) -> bool:
	var local: Vector2 = to_local(point)
	var area: Rect2 = allowed_bounds(margin)
	# Transform round trips can move an edge point by a few floating-point ULPs.
	return local.x >= area.position.x - 0.0001 and local.x <= area.end.x + 0.0001 and local.y >= area.position.y - 0.0001 and local.y <= area.end.y + 0.0001

func clamp_world(point: Vector2, margin: float = 0.0) -> Vector2:
	var area: Rect2 = allowed_bounds(margin)
	return to_global(to_local(point).clamp(area.position, area.end))

func sample_world(rng: RandomNumberGenerator, margin: float = 0.0) -> Vector2:
	var area: Rect2 = allowed_bounds(margin)
	return to_global(Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)))

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(bounds, Color(0.4, 0.9, 0.7, 0.08))
		draw_rect(bounds, Color(0.4, 0.9, 0.7, 0.8), false, 1.0)
