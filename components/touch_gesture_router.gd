class_name TouchGestureRouter
extends RefCounted
## Own each finger until release. UI fingers never become world gestures.
signal movement_changed(direction: Vector2)
signal action_requested(role: StringName)
signal tapped(point: Vector2)
signal pinched(ratio: float)
signal pinch_started

const TAP_DISTANCE: float = 12.0
const TAP_TIME_MS: int = 600
var fingers: Dictionary[int, Dictionary] = {}
var joystick_id: int = -1
var joystick_center: Vector2
var joystick_radius: float = 32.0
var direction: Vector2 = Vector2.ZERO
var _pinch_distance: float = 0.0

func begin(index: int, point: Vector2, role: StringName) -> void:
	if fingers.has(index):
		return
	if role == &"joystick":
		if joystick_id >= 0:
			role = &"ignored"
		else:
			joystick_id = index
	fingers[index] = {"role": role, "origin": point, "point": point, "moved": false,
		"suppressed": false, "started": Time.get_ticks_msec()}
	if role == &"joystick":
		_move_joystick(point)
	elif role in [&"tool", &"interact"]:
		action_requested.emit(role)
	_update_pinch(false)

func drag(index: int, point: Vector2) -> void:
	if not fingers.has(index):
		return
	var finger: Dictionary = fingers[index]
	finger.point = point
	if point.distance_to(finger.origin) > TAP_DISTANCE:
		finger.moved = true
	if index == joystick_id:
		_move_joystick(point)
	_update_pinch(true)

func end(index: int, point: Vector2, canceled: bool = false) -> void:
	if not fingers.has(index):
		return
	var finger: Dictionary = fingers[index]
	fingers.erase(index)
	if index == joystick_id:
		joystick_id = -1
		direction = Vector2.ZERO
		movement_changed.emit(direction)
	var tap: bool = finger.role == &"world" and not canceled and not finger.moved and not finger.suppressed
	tap = tap and point.distance_to(finger.origin) <= TAP_DISTANCE and Time.get_ticks_msec() - int(finger.started) <= TAP_TIME_MS
	_update_pinch(false)
	if tap:
		tapped.emit(point)

func cancel() -> void:
	fingers.clear()
	joystick_id = -1
	_pinch_distance = 0.0
	direction = Vector2.ZERO
	movement_changed.emit(direction)

func _move_joystick(point: Vector2) -> void:
	var offset: Vector2 = (point - joystick_center) / maxf(joystick_radius, 1.0)
	var strength: float = clampf((offset.length() - 0.15) / 0.85, 0.0, 1.0)
	direction = offset.normalized() * strength
	movement_changed.emit(direction)

func _update_pinch(emit_change: bool) -> void:
	var world: Array[int] = []
	for index: int in fingers:
		if fingers[index].role == &"world":
			world.append(index)
	if world.size() < 2:
		_pinch_distance = 0.0
		return
	if is_zero_approx(_pinch_distance):
		pinch_started.emit()
	# A third finger changes the pair only after a release. All are tap-suppressed.
	for index: int in world:
		fingers[index].suppressed = true
	var a: Vector2 = fingers[world[0]].point
	var b: Vector2 = fingers[world[1]].point
	var distance: float = a.distance_to(b)
	if emit_change and _pinch_distance >= 8.0 and distance >= 8.0:
		pinched.emit(distance / _pinch_distance)
	_pinch_distance = distance
