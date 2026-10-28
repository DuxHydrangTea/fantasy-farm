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
	basket = get_node("Basket") as InventoryComponent
	badge = get_node("Badge") as Label
	badge.resized.connect(_place_badge)
	sprite = get_node("Sprite") as AnimatedSprite2D
	collision = get_node("Collision") as CollisionShape2D
	movement = get_node("Movement") as MovementComponent
	animation = get_node("Animation") as AnimationComponent
	animation.animated_sprite = sprite
	behaviour = get_node("Behaviour") as WorkerBehaviourComponent
	behaviour.movement = movement
	behaviour.animation = animation

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
	movement.speed = definition.move_speed
	animation.single_direction_faces_left = definition.faces_left

func configure_patrol(points: Array[Vector2]) -> void:
	behaviour.patrol_points = points.duplicate()
	behaviour.begin_patrol(global_position)

func _place_badge() -> void:
	badge.position = Vector2(-badge.size.x * badge.scale.x * 0.5, -25.0 - badge.size.y * badge.scale.y)
