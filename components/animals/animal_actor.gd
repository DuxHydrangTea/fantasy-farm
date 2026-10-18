extends CharacterBody2D

const Definition = preload("res://scripts/animals/animal_definition.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Needs = preload("res://components/animals/animal_needs_component.gd")
const Wander = preload("res://components/animals/animal_wander_component.gd")
const Behaviour = preload("res://components/animals/animal_behaviour_component.gd")
@export var definition: Definition
@export var pen: Pen
@export var skin_frames: SpriteFrames
@export var show_needs: bool = true
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var movement: MovementComponent = $MovementComponent
@onready var animation: AnimationComponent = $AnimationComponent
@onready var needs: Needs = $NeedsComponent
@onready var wander: Wander = $WanderComponent
@onready var behaviour: Behaviour = $BehaviourComponent

func _ready() -> void:
	if pen == null:
		pen = get_parent() as Pen
	if definition == null or not definition.is_valid():
		wander.set_physics_process(false)
		return
	movement.speed = definition.move_speed
	animation.single_direction_faces_left = definition.faces_left
	sprite.sprite_frames = skin_frames if definition.has_movement_frames(skin_frames) else definition.adult_frames
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
	var visible_rect: Rect2i = texture.get_image().get_used_rect()
	sprite.position.y = texture.get_height() * 0.5 - visible_rect.end.y
	$NeedsDisplay.position.y = sprite.position.y - texture.get_height() * 0.5 + visible_rect.position.y - 18.0
	$NeedsDisplay.visible = show_needs
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = definition.footprint
	$CollisionShape2D.shape = shape
	needs.configure(definition.satiety_depletion_seconds, definition.hydration_depletion_seconds)
	needs.changed.connect(_update_needs_display)
	_update_needs_display(needs.satiety, needs.hydration)
	wander.pen = pen
	wander.idle_seconds = definition.idle_seconds
	wander.margin = maxf(definition.pen_margin, definition.footprint.length() * 0.5)
	animation.play("idle")
	behaviour.configure(definition)

func _update_needs_display(food: float, water: float) -> void:
	$NeedsDisplay/Satiety.value = food
	$NeedsDisplay/Hydration.value = water
