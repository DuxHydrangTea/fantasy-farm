class_name MovementComponent
extends Node

@export var speed: float = 150.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600
var body: CharacterBody2D

func _ready() -> void:
	body = get_parent() as CharacterBody2D
	assert(body != null, "MovementComponent phai la con truc tiep cua CharacterBody2D")

func move(dir: Vector2, delta: float):
	var target_velocity = dir.limit_length(1.0) * speed
	var rate := acceleration if not dir.is_zero_approx() else friction
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
	body.move_and_slide()

func stop():
	body.velocity = Vector2.ZERO
