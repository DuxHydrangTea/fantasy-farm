extends Node
## Habitat traversal and shore delivery, attached only inside a PondPen.
const Pond = preload("res://components/animals/pond_pen.gd")
const Behaviour = preload("res://components/animals/animal_behaviour_component.gd")
var actor: CharacterBody2D
var pen: Pond
var _points: PackedVector2Array = PackedVector2Array()
var _next: int = 0
var destination: Vector2
var _returning: bool = false
var _was_swimming: bool = false

func configure(body: CharacterBody2D, habitat: Pond) -> void:
	actor = body
	pen = habitat
	actor.wander.traversal = self
	actor.animation.action_mapper = map_action
	actor.animation.play("idle", true)

func is_swimming() -> bool:
	return actor.definition.can_swim and pen.is_water(actor.global_position)

func map_action(action: String) -> String:
	if not is_swimming():
		return action
	if action == "walk":
		return "swim"
	return "swim_sleep" if action == "sleep" else "swim_idle"

func refresh_visual() -> void:
	if not pen.navigation_ready:
		return
	if not actor.definition.can_swim and pen.is_water(actor.global_position):
		actor.global_position = pen.closest_land(actor.global_position)
		cancel()
	var swimming: bool = is_swimming()
	if swimming != _was_swimming:
		_was_swimming = swimming
		actor.animation.play(actor.animation.current_action)
		var texture: Texture2D = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, 0)
		var used: Rect2i = texture.get_image().get_used_rect()
		actor.sprite.position.y = texture.get_height() * 0.5 - used.end.y
		actor.get_node("NeedsDisplay").position.y = actor.sprite.position.y - texture.get_height() * 0.5 + used.position.y - 18.0

func can_reach(point: Vector2) -> bool:
	return not pen.route(actor.global_position, point, actor.definition.can_swim).is_empty()

func set_destination(point: Vector2) -> bool:
	_points = pen.route(actor.global_position, point, actor.definition.can_swim)
	_next = 0
	destination = point
	if _points.is_empty():
		actor.movement.cancel_target()
		return false
	actor.movement.set_target(_points[_next])
	return true

func distance_remaining() -> float:
	var distance: float = 0.0
	var before: Vector2 = actor.global_position
	for index: int in range(_next, _points.size()):
		distance += before.distance_to(_points[index])
		before = _points[index]
	return distance

func cancel() -> void:
	_points.clear()
	_next = 0
	actor.movement.cancel_target()
	actor.movement.stop()

func travel(delta: float) -> void:
	actor.movement.move_to_target(delta)
	if not actor.movement.has_target:
		# A blocked waypoint invalidates the route; never skip through a wall.
		if _next < _points.size() and actor.global_position.distance_to(_points[_next]) > 2.0:
			cancel()
			return
		_next += 1
		if _next < _points.size():
			actor.movement.set_target(_points[_next])

func handle_laying(delta: float) -> bool:
	if not actor.definition.eggs_on_land or actor.production.stored_amount <= 0:
		return false
	if not pen.is_water(actor.global_position):
		if _returning:
			_returning = false
			cancel()
			actor.behaviour.request_behaviour(&"idle")
		actor._on_produced(0)
		return false
	if not pen.navigation_ready:
		return true
	if actor.behaviour.current_state in [Behaviour.State.REST, Behaviour.State.SLEEP]:
		actor.behaviour.wake()
		return true
	if not _returning or not actor.movement.has_target:
		actor.foraging.cancel()
		actor.behaviour.request_behaviour(&"idle")
		_points = pen.land_route(actor.global_position)
		_next = 0
		if _points.is_empty():
			actor.movement.stop()
			return true
		destination = _points[-1]
		actor.movement.set_target(_points[0])
		_returning = true
	var before: Vector2 = actor.global_position
	travel(delta)
	var motion: Vector2 = actor.global_position - before
	actor.animation.update_facing_direction(motion)
	actor.animation.play("walk" if not motion.is_zero_approx() else "idle")
	return true
