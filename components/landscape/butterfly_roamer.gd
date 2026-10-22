extends "res://components/landscape/ambient_flutter.gd"
## Independent cosmetic visitor. Time is active gameplay seconds, unaffected by FPS.
enum FlightState { ROAM, GARDEN, LEAVING }
@export var roam_bounds: Rect2 = Rect2(24, 32, 2496, 1640)
@export var garden_bounds: Rect2 = Rect2(1432, 296, 368, 256)
@export var garden_visit_seconds: float = 30.0
@export var garden_cooldown_seconds: float = 300.0
var flight_state: FlightState = FlightState.ROAM
var _visit_until: float = 0.0
var _cooldown_until: float = 0.0
var _resume_target: Vector2

func _ready() -> void:
	radius = roam_bounds.size * 0.5
	super._ready()
	position = _bounded(position)
	_to = position
	_resume_target = position

func _process(delta: float) -> void:
	if speed <= 0.0:
		return
	# End the visit by its fixed deadline, even halfway through a curved flight.
	if flight_state == FlightState.GARDEN and _elapsed + delta >= _visit_until:
		_leave_garden()
	super._process(delta)
	if flight_state == FlightState.LEAVING:
		if not garden_bounds.grow(48.0).has_point(position):
			flight_state = FlightState.ROAM
			var destination: Vector2 = _resume_target
			if garden_bounds.grow(96.0).has_point(destination):
				destination = _roam_destination()
			_begin_leg(destination)
	elif flight_state == FlightState.ROAM and _elapsed >= _cooldown_until and garden_bounds.has_point(position):
		_enter_garden()

func _bounded(point: Vector2) -> Vector2:
	return point.clamp(roam_bounds.position, roam_bounds.end)

func _random_point(area: Rect2) -> Vector2:
	return Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))

func _roam_destination() -> Vector2:
	# Mix nearby wandering with cross-map journeys; there is no fixed home radius.
	if _rng.randf() < 0.35:
		return _random_point(roam_bounds.grow(-16.0))
	var angle: float = _rng.randf_range(0.0, TAU)
	return _bounded(position + Vector2(cos(angle), sin(angle)) * _rng.randf_range(160.0, 480.0))

func _start_leg() -> void:
	var destination: Vector2
	if flight_state == FlightState.GARDEN:
		destination = _random_point(garden_bounds.grow(-12.0).intersection(roam_bounds))
	elif flight_state == FlightState.LEAVING:
		destination = _exit_destination()
	else:
		destination = _roam_destination()
	_begin_leg(destination)

func _begin_leg(destination: Vector2) -> void:
	super._begin_leg(destination)
	var direction: Vector2 = (_to - _from).normalized()
	var distance: float = _from.distance_to(_to)
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var bend: float = _rng.randf_range(-1.0, 1.0) * minf(distance * 0.4, 64.0)
	_control_a = _bounded(_from + direction * distance * 0.3 + normal * bend)
	_control_b = _bounded(_to - direction * distance * 0.3 + normal * bend)
	_travel_duration = clampf(distance / (32.0 * speed / 0.6), 1.2, 90.0)

func _enter_garden() -> void:
	_resume_target = _to
	flight_state = FlightState.GARDEN
	_visit_until = _elapsed + garden_visit_seconds
	_start_leg()

func _leave_garden() -> void:
	flight_state = FlightState.LEAVING
	# The five-minute lock starts at the END of the visit, never at each flower.
	_cooldown_until = _visit_until + garden_cooldown_seconds
	_start_leg()

func _exit_destination() -> Vector2:
	var center: Vector2 = garden_bounds.get_center()
	var candidates: PackedVector2Array = PackedVector2Array([
		Vector2(garden_bounds.position.x - 96.0, center.y),
		Vector2(garden_bounds.end.x + 96.0, center.y),
		Vector2(center.x, garden_bounds.position.y - 96.0),
		Vector2(center.x, garden_bounds.end.y + 96.0)])
	var best: Vector2 = _bounded(candidates[0])
	for point: Vector2 in candidates:
		var candidate: Vector2 = _bounded(point)
		if candidate.distance_squared_to(position) < best.distance_squared_to(position):
			best = candidate
	return best
