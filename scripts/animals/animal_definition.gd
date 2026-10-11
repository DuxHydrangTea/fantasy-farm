class_name AnimalDefinition
extends Resource

@export var animal_id: StringName
@export var display_name: String
@export var species: AnimalTypes.Species = AnimalTypes.Species.CHICKEN

@export_group("Growth")
@export_range(0.0, 86400.0) var maturity_seconds: float = 120.0

@export_group("Needs")
@export_range(1.0, 86400.0) var satiety_depletion_seconds: float = 600.0 # độ no thức ăn
@export_range(1.0, 86400.0) var hydration_depletion_seconds: float = 600.0 # độ no nước

@export_range(1, 32000) var food_per_meal: int = 1
@export_range(1, 32000) var water_per_drink: int = 1

@export_group("Production")
@export var production: AnimalProductionDefination

@export_group("Visuals")
@export var adult_frames: SpriteFrames
@export var juvenile_frames: SpriteFrames

func is_valid() -> bool:
	if animal_id == &"":
		return false
		
	if maturity_seconds < 0.0:
		return false

	if satiety_depletion_seconds <= 0.0:
		return false

	if hydration_depletion_seconds <= 0.0:
		return false

	if food_per_meal <= 0 or water_per_drink <= 0:
		return false

	if adult_frames == null:
		return false
	
	if production != null:
		if not production.is_valid():
			return false
			
	return true

func get_frames_for_stage(is_adult: bool) -> SpriteFrames:
	if is_adult:
		return adult_frames
	
	if juvenile_frames == null:
		return adult_frames
		
	return juvenile_frames
