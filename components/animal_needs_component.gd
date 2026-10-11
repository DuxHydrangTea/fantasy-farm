class_name AnimalNeedsComponent
extends Node

signal needs_changed(satiety: float, hydration: float)
signal need_flags_changed(hungry: bool, thirsty: bool)

@export_range(0.0, 100.0) var initial_satiety: float = 100.0
@export_range(0.0, 100.0) var initial_hydration: float = 100.0
@export_range(0.0, 100.0) var seek_threshold: float = 100.0

var satiety: float = 100.0
var hydration: float = 100.0

var _definition: AnimalDefinition
var _initialized: bool = false

func initialize(definition: AnimalDefinition) -> bool:
	if definition == null:
		push_error("AnimalNeedsComponent: chưa gán AnimalDefination.")
		return false
	
	if not definition.is_valid():
		push_error("AnimalNeedsComponent: cấu hình vật nuôi không hợp lệ.")
		return false
		
	_definition = definition
	satiety = initial_satiety
	hydration = initial_hydration
	_initialized = true
	
	needs_changed.emit(satiety, hydration)
	need_flags_changed.emit(is_hungry(), is_thirsty())

	return true

func is_hungry() -> bool:
	return satiety <= seek_threshold
	
func is_thirsty() -> bool:
	return hydration <= seek_threshold
	
func is_initialized() -> bool:
	return _initialized
	
func can_support_growth_and_production() -> bool:
	return _initialized and satiety > 0.0 and hydration > 0.0
	
func advance_time(seconds: float) -> void:
	if not _initialized:
		return
		
	if seconds <= 0.0:
		return
		
	var satiety_loss := (100 / _definition.satiety_depletion_seconds) * seconds
	var hydration_loss := (100 / _definition.hydration_depletion_seconds) * seconds
	
	_set_needs(satiety - satiety_loss, hydration - hydration_loss)

func _set_needs(new_satiety: float, new_hydration: float) -> void:
	var was_hungry := is_hungry()
	var was_thirsty := is_thirsty()
	
	var old_satiety := satiety
	var old_hydration := hydration
	
	satiety = clampf(new_satiety, 0.0, 100.0)
	hydration = clampf(new_hydration, 0.0, 100.0)
	
	if satiety == old_satiety and hydration == old_hydration:
		return
		
	needs_changed.emit(satiety, hydration)
	
	if was_hungry != is_hungry() or was_thirsty != is_thirsty():
		need_flags_changed.emit(is_hungry(), is_thirsty())

func restore_satiety() -> void:
	if not _initialized:
		return
	
	_set_needs(100.0, hydration)

func restore_hydration() -> void:
	if not _initialized:
		return
	
	_set_needs(satiety, 100.0)
