class_name BeehiveRangeDisplay
extends Node2D
var radius: float = 80.0
var allowed: bool = true
var footprint: bool = false
var garden_grid: bool = false
var garden_cell: Vector2i = Vector2i.ZERO
var garden: FlowerGarden

func _draw() -> void:
	var color: Color = Color(0.95,0.78,0.30,0.65) if allowed else Color(1,0.25,0.22,0.75)
	if garden_grid:
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				if (x != 0 or y != 0) and is_instance_valid(garden) and garden.pots.has(garden_cell + Vector2i(x, y)):
					var pot: FlowerPot = garden.pots[garden_cell + Vector2i(x, y)]
					var offset: Vector2 = to_local(pot.global_position)
					draw_rect(Rect2(offset - Vector2(11, 9), Vector2(22, 18)),color,false,1.0)
		return
	draw_circle(Vector2.ZERO,radius,Color(color,0.06))
	draw_arc(Vector2.ZERO,radius,0,TAU,65,color,1.0)
	if footprint:
		draw_rect(Rect2(-8,-8,16,16),color,false,1.0)
