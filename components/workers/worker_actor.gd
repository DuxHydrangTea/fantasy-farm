class_name WorkerActor
extends CharacterBody2D
## Generic hired-worker body. Composition mirrors AnimalActor: movement +
## animation + behaviour are child components wired by type, never by node
## name. The M0 patrol remains available; hired instances use WorkerService
## for their role, basket and shared online/offline task timeline.
@export var definition: WorkerDefinition
@export var persistent_id: StringName

var worker_service: WorkerService
var worker_role: String = ""
var basket: InventoryComponent
var badge: Label

var sprite: AnimatedSprite2D
var collision: CollisionShape2D
var movement: MovementComponent
var animation: AnimationComponent
var behaviour: WorkerBehaviourComponent

func _enter_tree() -> void:
	if movement != null:
		return
	basket = InventoryComponent.new()
	basket.starting_tools = false
	basket.slot_count = 16
	basket.stack_cap = 100
	add_child(basket)
	badge = Label.new()
	badge.theme = preload("res://resources/ui/game_theme.tres")
	badge.resized.connect(_place_badge)
	badge.scale = Vector2(0.35, 0.35)
	badge.z_index = 20
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	badge.add_theme_constant_override("outline_size", 2)
	add_child(badge)
	# Components are configured before entering the tree: AnimationComponent
	# asserts its sprite reference in its own _ready.
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	collision = CollisionShape2D.new()
	collision.name = "Collision"
	add_child(collision)
	movement = MovementComponent.new()
	movement.name = "Movement"
	add_child(movement)
	animation = AnimationComponent.new()
	animation.name = "Animation"
	animation.animated_sprite = sprite
	add_child(animation)
	behaviour = WorkerBehaviourComponent.new()
	behaviour.name = "Behaviour"
	behaviour.movement = movement
	behaviour.animation = animation
	add_child(behaviour)
	# Same physical family as animals: collides with world statics, never
	# blocks farming queries (obstacle_mask is the World layer only).
	collision_layer = 4
	collision_mask = 1

func _ready() -> void:
	if persistent_id.is_empty():
		persistent_id = StringName("worker_" + Crypto.new().generate_random_bytes(16).hex_encode())
	add_to_group(&"grass_interactors")
	if definition == null or not definition.is_valid():
		behaviour.set_physics_process(false)
		return
	_apply_definition()
	animation.play("idle")

func _apply_definition() -> void:
	sprite.sprite_frames = definition.frames
	movement.speed = definition.move_speed
	animation.single_direction_faces_left = definition.faces_left
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = definition.footprint
	collision.shape = shape
	var texture: Texture2D = definition.frames.get_frame_texture(&"idle_down", 0)
	if texture != null:
		var used: Rect2i = texture.get_image().get_used_rect()
		sprite.position.y = texture.get_height() * 0.5 - used.end.y

func configure_patrol(points: Array[Vector2]) -> void:
	behaviour.patrol_points = points.duplicate()
	behaviour.begin_patrol(global_position)

func _place_badge() -> void:
	badge.position = Vector2(-badge.size.x * badge.scale.x * 0.5, -25.0 - badge.size.y * badge.scale.y)
