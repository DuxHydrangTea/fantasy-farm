class_name ChickenCoop
extends Node2D

@export_range(0.1, 10.0) var needs_tick_seconds: float = 1.0
var _needs_components: Array[AnimalNeedsComponent] = []
var _elapsed: float = 0.0

func _ready() -> void:
	_collect_needs_components(self)

func _collect_needs_components(node: Node) -> void:
	for child in node.get_children():
		if child is AnimalNeedsComponent:
			register_needs(child)
		
		_collect_needs_components(child)

func register_needs(needs: AnimalNeedsComponent) -> void:
	if not is_instance_valid(needs):
		return
		
	if not needs.is_initialized():
		return
	
	if _needs_components.has(needs):
		return
		
	_needs_components.append(needs)

func _process(delta: float) -> void:
	_elapsed += delta
	
	if _elapsed < needs_tick_seconds:
		return
		
	var elapsed_seconds := _elapsed
	_elapsed = 0
	
	for index in range(_needs_components.size() -1, -1, -1):
		var needs := _needs_components[index]
		
		if not is_instance_valid(needs):
			_needs_components.remove_at(index)
			continue
			
		needs.advance_time(elapsed_seconds)

func find_nearest_feed_trough(
	from_postion: Vector2,
	defination: AnimalDefinition
) -> FeedTrough:
	var nearest: FeedTrough = null
	var nearest_distance: float = INF
	
	for child in get_children():
		var trough := child as FeedTrough
		
		if trough == null:
			continue
			
		if trough.animal_species != defination.species:
			continue
		
		if not trough.has_food(defination.food_per_meal):
			continue
			
		var distance := from_postion.distance_squared_to(
			trough.eat_point.global_position
		)
		
		if distance < nearest_distance:
			nearest = trough
			nearest_distance = distance
			
	return nearest
	
func find_nearest_water_trough(
	from_position: Vector2,
	definition: AnimalDefinition
) -> WaterTrough:
	var nearest: WaterTrough = null
	var nearest_distance: float = INF

	for child in get_children():
		var trough := child as WaterTrough

		if trough == null:
			continue

		if not trough.has_water(definition.water_per_drink):
			continue

		var distance := from_position.distance_squared_to(
			trough.drink_point.global_position
		)

		if distance < nearest_distance:
			nearest = trough
			nearest_distance = distance

	return nearest
