extends Node

const Clock = preload("res://components/time_manager.gd")
signal changed(satiety: float, hydration: float)
## Eligible time is measured BEFORE depletion, including partial last intervals.
signal time_advanced(timestamp: float, elapsed: float, supplied_seconds: float)
@export var time_manager: Clock
var satiety: float = 100.0
var hydration: float = 100.0
var satiety_depletion_seconds: float = 600.0
var hydration_depletion_seconds: float = 600.0
var _updated_at: float = 0.0

func _ready() -> void:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager") as Clock
	if time_manager != null:
		_updated_at = time_manager.now()
		time_manager.tick.connect(update_at)

func configure(food_seconds: float, water_seconds: float) -> void:
	satiety_depletion_seconds = maxf(1.0, food_seconds)
	hydration_depletion_seconds = maxf(1.0, water_seconds)

## Set a baseline without crediting the interval twice; update_at applies catch-up.
func restore_state(food: float, water: float, timestamp: float) -> void:
	_updated_at = timestamp
	_set_values(food, water)

func update_at(timestamp: float) -> void:
	var elapsed: float = maxf(0.0, timestamp - _updated_at)
	_updated_at = maxf(_updated_at, timestamp)
	var food_seconds: float = satiety * satiety_depletion_seconds / 100.0
	var water_seconds: float = hydration * hydration_depletion_seconds / 100.0
	var supplied: float = minf(elapsed, minf(food_seconds, water_seconds))
	_set_values(satiety - elapsed * 100.0 / satiety_depletion_seconds, hydration - elapsed * 100.0 / hydration_depletion_seconds)
	if elapsed > 0.0:
		time_advanced.emit(_updated_at, elapsed, supplied)

func feed(amount: float) -> float:
	_sync()
	var before: float = satiety
	_set_values(satiety + maxf(0.0, amount), hydration)
	return satiety - before

func drink(amount: float) -> float:
	_sync()
	var before: float = hydration
	_set_values(satiety, hydration + maxf(0.0, amount))
	return hydration - before

func _sync() -> void:
	if time_manager != null:
		update_at(time_manager.now())

func _set_values(food: float, water: float) -> void:
	var next_food: float = clampf(food, 0.0, 100.0)
	var next_water: float = clampf(water, 0.0, 100.0)
	if is_equal_approx(next_food, satiety) and is_equal_approx(next_water, hydration):
		return
	satiety = next_food
	hydration = next_water
	changed.emit(satiety, hydration)
