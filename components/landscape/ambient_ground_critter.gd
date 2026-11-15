extends Node2D
## Decorative animals travel between scene-authored points and rest at each end.

@export var roam_offset: Vector2 = Vector2(24, 0)
@export var initial_delay: float = 1.0
@export var rest_seconds: float = 4.0
@export_range(1.0, 100.0) var walk_speed: float = 13.0
@export var faces_left: bool = true
@export var shadow_radius: float = 9.0
@export var prepare_animation: StringName

@onready var _sprite: AnimatedSprite2D = $Sprite
var _home: Vector2
var _heading_out: bool = true

func _ready() -> void:
	_home = position
	_face(roam_offset.x)
	_rest(initial_delay)

func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, shadow_radius, Color(0.12, 0.17, 0.11, 0.32))

func _rest(delay: float) -> void:
	_sprite.play(&"idle")
	var pause: Tween = create_tween()
	pause.tween_interval(delay)
	pause.tween_callback(_prepare_move)

func _face(horizontal: float) -> void:
	if not is_zero_approx(horizontal):
		_sprite.flip_h = (horizontal > 0.0) == faces_left

func _prepare_move() -> void:
	if prepare_animation.is_empty():
		_walk()
		return
	_face(roam_offset.x if _heading_out else -roam_offset.x)
	_sprite.animation_finished.connect(_walk, CONNECT_ONE_SHOT)
	_sprite.play(prepare_animation)

func _walk() -> void:
	var target: Vector2 = _home + roam_offset if _heading_out else _home
	_face(target.x - position.x)
	_sprite.play(&"walk")
	var movement: Tween = create_tween()
	movement.tween_property(self, "position", target, position.distance_to(target) / walk_speed)
	movement.tween_callback(_rest.bind(rest_seconds))
	_heading_out = not _heading_out
