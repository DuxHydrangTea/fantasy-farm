extends AnimatedSprite2D
## Cosmetic flower-to-flower flight. Offsets and bounds are local to the parent.
@export var radius: Vector2 = Vector2(18, 9)
@export var speed: float = 0.6
@export var phase: float = 0.0
## Flower positions relative to the authored starting position. Empty uses local stops.
@export var flower_stops: PackedVector2Array = PackedVector2Array()
var _home: Vector2
var _elapsed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _from: Vector2
var _to: Vector2
var _control_a: Vector2
var _control_b: Vector2
var _travel_time: float = 0.0
var _travel_duration: float = 1.0
var _hover_time: float = 0.0
var _hover_duration: float = 1.0
var _hovering: bool = true
var _last_stop: int = -1
var _wing_speed: float = 0.6

func _ready() -> void:
	_home = position
	_to = _home
	_rng.seed = int(absf(phase) * 10000.0 + absf(_home.x) * 17.0 + absf(_home.y) * 31.0)
	_hover_duration = _rng.randf_range(0.2, 1.4)
	set_process(speed > 0.0 and radius.x > 0.0 and radius.y > 0.0)

func _process(delta: float) -> void:
	if speed <= 0.0 or radius.x <= 0.0 or radius.y <= 0.0:
		return
	_elapsed += delta
	var previous: Vector2 = position
	if _hovering:
		_hover_time += delta
		# Tiny hovering movements keep the two-frame art alive near each flower.
		position = _bounded(_to + Vector2(sin(_hover_time * 2.3) * 0.35, sin(_hover_time * 3.4) * 0.65))
		if _hover_time >= _hover_duration:
			_start_leg()
	else:
		_travel_time = minf(_travel_time + delta, _travel_duration)
		var progress: float = _travel_time / _travel_duration
		var eased: float = smoothstep(0.0, 1.0, progress)
		var flutter: Vector2 = Vector2(sin(_elapsed * 10.0 + phase) * 0.45, sin(_elapsed * 7.3 + phase) * 0.7) * sin(PI * progress)
		position = _bounded(_from.bezier_interpolate(_control_a, _control_b, _to, eased) + flutter)
		if _travel_time >= _travel_duration:
			position = _to
			_hovering = true
			_hover_time = 0.0
			_hover_duration = _rng.randf_range(0.7, 1.8)
			_wing_speed = _rng.randf_range(0.4, 0.65)
	var horizontal: float = position.x - previous.x
	if not _hovering and absf(horizontal) > delta * 2.0:
		flip_h = horizontal < 0.0
	speed_scale = move_toward(speed_scale, _wing_speed, delta * 1.5)

func _bounded(point: Vector2) -> Vector2:
	return point.clamp(_home - radius, _home + radius)

func _start_leg() -> void:
	_from = position
	if flower_stops.size() >= 2:
		# Choose a different flower each time; never teleport to an endpoint.
		var index: int = _rng.randi_range(0, flower_stops.size() - (2 if _last_stop >= 0 else 1))
		if _last_stop >= 0 and index >= _last_stop:
			index += 1
		_last_stop = index
		_to = _bounded(_home + flower_stops[index])
	else:
		# Fallback for newly placed butterflies without hand-authored flowers.
		var angle: float = _rng.randf_range(0.0, TAU)
		_to = _home + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * 0.7
	_begin_leg(_to)

func _begin_leg(destination: Vector2) -> void:
	_from = position
	_to = _bounded(destination)
	var direction: Vector2 = (_to - _from).normalized()
	var distance: float = _from.distance_to(_to)
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var bend: float = _rng.randf_range(-0.4, 0.4) * minf(distance, radius.y * 2.0)
	_control_a = _bounded(_from + direction * distance * 0.3 + normal * bend)
	_control_b = _bounded(_to - direction * distance * 0.3 + normal * bend)
	_travel_duration = clampf(distance / (22.0 * speed / 0.6), 1.2, 5.0)
	_travel_time = 0.0
	_hovering = false
	_wing_speed = _rng.randf_range(0.85, 1.15)
