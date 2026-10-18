class_name FacingComponent
extends Node

signal facing_direction_changed(facing_direction: Vector2)
var facing_direction := Vector2.DOWN

func set_direction(dir: Vector2) -> void:
	if dir.is_zero_approx():
		return
	
	var next_facing: Vector2
	
	if absf(dir.x) > absf(dir.y):
		next_facing = Vector2.RIGHT if dir.x > 0.0 else Vector2.LEFT
	else:
		next_facing = Vector2.DOWN if dir.y > 0.0 else Vector2.UP
		
	if next_facing == facing_direction:
		return
		
	facing_direction = next_facing
	facing_direction_changed.emit(facing_direction)
