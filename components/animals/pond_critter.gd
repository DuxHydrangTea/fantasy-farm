extends Node2D
## Decorative frogs croak and hop along short, scene-authored routes.

@export var roam_offset: Vector2
@export var initial_delay: float = 1.0
@export var rest_seconds: float = 4.0

@onready var _sprite: AnimatedSprite2D = $Sprite
var _home: Vector2
var _at_home: bool = true

func _ready() -> void:
	_home = position
	_rest(initial_delay)

func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.29))
	draw_circle(Vector2.ZERO, 4.5, Color(0.12, 0.17, 0.11, 0.32))

func _rest(delay: float) -> void:
	_sprite.play(&"idle_right")
	var pause: Tween = create_tween()
	pause.tween_interval(delay)
	pause.tween_callback(_act)

func _act() -> void:
	_sprite.animation_finished.connect(_after_croak, CONNECT_ONE_SHOT)
	_sprite.play(&"croak_right")

func _after_croak() -> void:
	if roam_offset.is_zero_approx():
		_rest(rest_seconds)
	else:
		_move()

func _move() -> void:
	var start: Vector2 = position
	var target: Vector2 = _home + roam_offset if _at_home else _home
	_sprite.flip_h = target.x < start.x
	_sprite.play(&"idle_right")
	var movement: Tween = create_tween()
	movement.tween_method(_advance.bind(start, target), 0.0, 1.0, 0.38)
	movement.tween_callback(_rest.bind(rest_seconds))
	_at_home = not _at_home

func _advance(progress: float, start: Vector2, target: Vector2) -> void:
	position = start.lerp(target, progress)
	_sprite.position.y = -roundf(sin(progress * PI) * 6.0)
