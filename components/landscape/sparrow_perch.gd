extends AnimatedSprite2D
## A yard bird rests on authored perches and flies away from an approaching player.

const STARTLE_DISTANCE: float = 42.0
const FLIGHT_SPEED: float = 110.0

@export var alternate_perches: PackedVector2Array
## Offset from the visible perch to the spot on the ground beneath it.
@export var approach_offset: Vector2 = Vector2(0, 20)

var _home: Vector2
var _player: Node2D
var _check_in: float = 0.0

func _ready() -> void:
	_home = position
	play(&"idle")

func _process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = 0.15
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = _local_player()
	if _player == null:
		return
	var ground: Vector2 = (get_parent() as Node2D).to_local(_player.global_position) - approach_offset
	var distance: float = position.distance_squared_to(ground)
	if distance > STARTLE_DISTANCE * STARTLE_DISTANCE:
		return
	var destination: Vector2 = position
	var candidates: PackedVector2Array = alternate_perches.duplicate()
	candidates.append(_home)
	for perch: Vector2 in candidates:
		var clearance: float = perch.distance_squared_to(ground)
		if clearance > distance:
			destination = perch
			distance = clearance
	if destination != position:
		_fly_to(destination)

func _local_player() -> Node2D:
	for candidate: Node in get_tree().get_nodes_in_group(&"farm_players"):
		if candidate is Node2D and candidate.get_parent().is_ancestor_of(self):
			return candidate as Node2D
	return null

func _fly_to(destination: Vector2) -> void:
	var origin: Vector2 = position
	flip_h = destination.x < origin.x
	play(&"fly")
	set_process(false)
	var flight: Tween = create_tween()
	var duration: float = clampf(origin.distance_to(destination) / FLIGHT_SPEED, 0.4, 1.8)
	flight.tween_method(_flight_step.bind(origin, destination), 0.0, 1.0, duration)
	flight.tween_callback(_land.bind(destination))

func _flight_step(progress: float, from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, progress) + Vector2.UP * sin(progress * PI) * 22.0

func _land(destination: Vector2) -> void:
	position = destination
	play(&"idle")
	_check_in = 1.25
	set_process(true)
