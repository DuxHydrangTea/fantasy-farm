extends Node2D
## A fixed population with no spawning timers, physics, navigation or save state.
const ROAMER: Script = preload("res://components/landscape/butterfly_roamer.gd")
const COLORS: Array[SpriteFrames] = [
	preload("res://sprite_frames/animals/butterfly_01_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_02_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_03_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_04_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_05_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_06_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_07_frames.tres"),
	preload("res://sprite_frames/animals/butterfly_08_frames.tres")]
@export_range(1, 128, 1) var population: int = 48
@export var roam_bounds: Rect2 = Rect2(24, 32, 2496, 1640)
@export var garden_bounds: Rect2 = Rect2(1432, 296, 368, 256)
@export var garden_visit_seconds: float = 30.0
@export var garden_cooldown_seconds: float = 300.0
## Zero randomizes on each launch. A nonzero value allows reproducible previews.
@export var random_seed: int = 0

func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	var columns: int = 8
	var rows: int = ceili(float(population) / columns)
	for index: int in range(population):
		var butterfly: AnimatedSprite2D = ROAMER.new() as AnimatedSprite2D
		butterfly.name = "Butterfly_%02d" % (index + 1)
		# Jittered cells distribute butterflies across the whole map from startup.
		var cell: Vector2 = Vector2(index % columns, floori(float(index) / columns))
		var fraction: Vector2 = (cell + Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85))) / Vector2(columns, rows)
		butterfly.position = roam_bounds.position + fraction * roam_bounds.size
		butterfly.sprite_frames = COLORS[rng.randi_range(0, COLORS.size() - 1)]
		butterfly.set("speed", rng.randf_range(0.55, 0.85))
		butterfly.set("phase", rng.randf_range(0.0, TAU))
		butterfly.set("roam_bounds", roam_bounds)
		butterfly.set("garden_bounds", garden_bounds)
		butterfly.set("garden_visit_seconds", garden_visit_seconds)
		butterfly.set("garden_cooldown_seconds", garden_cooldown_seconds)
		add_child(butterfly)
		butterfly.play(&"fly")
		butterfly.frame = rng.randi_range(0, 1)
