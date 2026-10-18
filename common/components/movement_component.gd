class_name MovementComponent
extends Node

@export var body: CharacterBody2D
@export_range(0.0, 500.0) var speed: float = 150.0

var _dir := Vector2.ZERO

func _ready() -> void:
	assert(body != null, "CharacterBody2D chưa được gán!")

func set_direction(dir: Vector2) -> void:
	_dir = dir.limit_length(1.0)

func _physics_process(_delta: float) -> void:
	body.velocity = _dir * speed
	body.move_and_slide()
