class_name FeedTrough
extends StaticBody2D

signal food_changed(amount:int, capacity: int)

@export var animal_species: AnimalTypes.Species = AnimalTypes.Species.CHICKEN
@export_range(1, 32000) var capacity: int = 32000
@export var empty_region: Rect2 = Rect2(144, 0, 16, 32)
@export var filled_region: Rect2 = Rect2(96, 0, 16, 32)
@export_range(0, 32000) var food_amount: int = 0:
	set(value):
		var new_amount := clampi(value, 0, capacity)

		if food_amount == new_amount:
			return

		food_amount = new_amount

		if not is_node_ready():
			return

		_update_visual()
		food_changed.emit(food_amount, capacity)

@onready var sprite: Sprite2D = $Sprite2D
@onready var eat_point: Marker2D = $EatPoint

func _ready() -> void:
	_update_visual()
	food_changed.emit(food_amount, capacity)

func _update_visual() -> void:
	if food_amount > 0:
		sprite.region_rect = filled_region
	else:
		sprite.region_rect = empty_region

func try_consume(amount: int) -> bool:
	if not has_food(amount):
		return false

	food_amount -= amount
	return true
	
func has_food(amount: int = 1) -> bool:
	if amount <= 0:
		return false
	
	return food_amount >= amount
	
func get_free_capacity() -> int:
	return maxi(0, capacity - food_amount)

func add_food(amount: int) -> int:
	if amount <= 0:
		return 0
	
	var accepted_amount := mini(amount, get_free_capacity())
	
	if accepted_amount == 0:
		return 0
		
	food_amount += accepted_amount
	
	return accepted_amount
