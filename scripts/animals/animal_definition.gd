class_name AnimalDefinition
extends Resource

@export var animal_id: StringName
@export var display_name: String
@export var species: AnimalTypes.Species = AnimalTypes.Species.CHICKEN
@export_group("Movement")
@export_range(1.0, 150.0) var move_speed: float = 28.0
@export var idle_seconds: Vector2 = Vector2(0.6, 1.8)
@export var footprint: Vector2 = Vector2(10, 6)
@export_range(1.0, 64.0) var pen_margin: float = 12.0
@export_group("Behaviour")
@export_range(0.0, 20.0) var walk_weight: float = 5.0
@export_range(0.0, 20.0) var forage_weight: float = 3.0
@export_range(0.0, 20.0) var rest_weight: float = 1.0
@export_range(0.0, 20.0) var sleep_weight: float = 1.0
@export var forage_seconds: Vector2 = Vector2(1.5, 3.5)
@export var rest_seconds: Vector2 = Vector2(2.0, 4.0)
@export var sleep_seconds: Vector2 = Vector2(4.0, 8.0)
## Empty uses the first supported animation (peck/graze/chew, sit/lie_down).
@export var forage_action: StringName = &""
@export var lie_down_action: StringName = &""
@export_group("Needs")
@export_range(1.0, 86400.0) var satiety_depletion_seconds: float = 600.0
@export_range(1.0, 86400.0) var hydration_depletion_seconds: float = 600.0
@export_range(1, 32000) var food_per_meal: int = 1
@export_range(1, 32000) var water_per_drink: int = 1
@export_range(0.0, 100.0) var food_seek_threshold: float = 50.0
@export_range(0.0, 100.0) var water_seek_threshold: float = 50.0
@export_group("Visuals")
@export var adult_frames: SpriteFrames
@export var juvenile_frames: SpriteFrames
@export var faces_left: bool = true
@export_group("Habitat")
@export var can_swim: bool = false
@export var eggs_on_land: bool = false
@export_group("Growth And Production")
@export_range(0.0, 86400.0) var maturity_seconds: float = 120.0
@export var production: AnimalProductionDefinition

func is_valid() -> bool:
	return not animal_id.is_empty() and has_movement_frames(adult_frames) and move_speed > 0.0 and footprint.x > 0.0 and footprint.y > 0.0 and satiety_depletion_seconds > 0.0 and hydration_depletion_seconds > 0.0 and idle_seconds.x >= 0.0 and idle_seconds.y >= idle_seconds.x

func has_movement_frames(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation(&"idle_down") and frames.has_animation(&"walk_down") and frames.get_frame_count(&"idle_down") > 0 and frames.get_frame_count(&"walk_down") > 0

func get_frames_for_stage(is_adult: bool) -> SpriteFrames:
	return adult_frames if is_adult or not has_movement_frames(juvenile_frames) else juvenile_frames
