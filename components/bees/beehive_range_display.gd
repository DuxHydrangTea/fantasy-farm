class_name BeehiveRangeDisplay
extends Node2D
var radius: float = 80.0
var allowed: bool = true
var footprint: bool = false

func _draw() -> void:
	var color: Color = Color(0.95,0.78,0.30,0.65) if allowed else Color(1,0.25,0.22,0.75)
	draw_circle(Vector2.ZERO,radius,Color(color,0.06))
	draw_arc(Vector2.ZERO,radius,0,TAU,65,color,1.0)
	if footprint:
		draw_rect(Rect2(-8,-8,16,16),color,false,1.0)
