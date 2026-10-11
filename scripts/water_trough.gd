class_name WaterTrough
extends StaticBody2D

signal water_changed(amount:int, capacity: int)

@onready var sprite: Sprite2D = $Sprite2D
@onready var drink_point: Marker2D = $DrinkPoint

@export var empty_region: Rect2
@export var filled_region: Rect2
@export_range(1, 32000) var capacity = 32000
@export var water_amount: int = 0:
	set(value):
		var new_amount := clampi(value, 0, capacity)
		
		if water_amount == new_amount:
			return
		water_amount = new_amount
		
		if not is_node_ready():
			return
			
		_update_visual()
		water_changed.emit(new_amount, capacity)
		
func _update_visual() -> void:
	if not is_instance_valid(sprite):
		return
	if water_amount > 0:
		sprite.region_rect = filled_region
	else:
		sprite.region_rect = empty_region		

func _ready() -> void:
	_update_visual()
	water_changed.emit(water_amount, capacity)


func get_free_capacity() -> int:
	return maxi(0, capacity - water_amount)

func has_water(amount: int = 1) ->bool:
	if amount <= 0:
		return false
	
	return water_amount >= amount

func add_water(amount: int) -> int:
	if amount <= 0:
		return 0
	
	var accepted_amount := mini(amount, get_free_capacity())
	
	if accepted_amount == 0:
		return 0
		
	water_amount += accepted_amount
	
	return accepted_amount

func try_consume(amount: int) -> bool:
	if not has_water(amount):
		return false
	
	water_amount -= amount
	
	return true
