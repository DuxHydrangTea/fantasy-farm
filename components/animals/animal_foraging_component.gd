class_name AnimalForagingComponent
extends Node
## Species-independent supply selection, reservations, travel and consumption.
## Behaviour owns the animation/state transitions; Needs owns food/water values.
enum Travel { MOVING, ARRIVED, FAILED }
var definition: AnimalDefinition
var needs: AnimalNeedsComponent
var wander: AnimalWanderComponent
var target: AnimalTrough
var target_slot: int = -1
var _retry_remaining: float = 0.0
var _travel_remaining: float = 0.0
var _blocked: Dictionary[int, float] = {}

func configure(data: AnimalDefinition, needs_component: AnimalNeedsComponent, wander_component: AnimalWanderComponent) -> void:
	definition = data
	needs = needs_component
	wander = wander_component

func advance(delta: float) -> void:
	_retry_remaining = maxf(0.0, _retry_remaining - delta)
	for identity: int in _blocked.keys():
		_blocked[identity] -= delta
		if _blocked[identity] <= 0.0:
			_blocked.erase(identity)

func has_need() -> bool:
	return definition != null and (needs.satiety <= definition.food_seek_threshold or needs.hydration <= definition.water_seek_threshold)

func priority_kinds() -> Array[int]:
	var kinds: Array[int] = []
	if needs.hydration <= definition.water_seek_threshold:
		kinds.append(AnimalTrough.Kind.WATER)
	if needs.satiety <= definition.food_seek_threshold:
		if kinds.is_empty() or needs.satiety < needs.hydration:
			kinds.push_front(AnimalTrough.Kind.FOOD)
		else:
			kinds.append(AnimalTrough.Kind.FOOD)
	return kinds

func try_begin() -> bool:
	if definition == null or not is_instance_valid(wander.pen) or _retry_remaining > 0.0 or not has_need():
		return false
	_retry_remaining = 0.75
	for supply_kind: int in priority_kinds():
		var best: AnimalTrough = null
		var best_slot: int = -1
		var best_distance: float = INF
		for candidate: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
			var trough: AnimalTrough = candidate as AnimalTrough
			if trough == null or trough.is_queued_for_deletion() or trough.pen != wander.pen or trough.kind != supply_kind or not trough.can_supply(definition) or _blocked.has(trough.get_instance_id()):
				continue
			for slot: int in range(trough.access_offsets.size()):
				var point: Vector2 = trough.access_position(slot)
				var distance: float = wander.movement.body.global_position.distance_squared_to(point)
				if distance >= best_distance or not trough.slot_available(slot, wander.movement.body) or not wander.pen.contains_world(point, wander.margin):
					continue
				if not wander._target_is_clear(point) or not _path_is_clear(point):
					continue
				best = trough
				best_slot = slot
				best_distance = distance
		if best != null and best.claim(wander.movement.body, best_slot, definition):
			target = best
			target_slot = best_slot
			if not wander.set_destination(best.access_position(best_slot)):
				cancel(true)
				return false
			_travel_remaining = maxf(5.0, wander.route_distance() / maxf(1.0, wander.movement.speed) * 2.0 + 2.0)
			return true
	return false

func target_is_valid() -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and is_instance_valid(wander.pen) and target.pen == wander.pen and target.can_supply(definition) and target.owns_slot(wander.movement.body, target_slot) and target_slot >= 0 and target_slot < target.access_offsets.size() and wander.pen.contains_world(target.access_position(target_slot), wander.margin)

func step(delta: float) -> Travel:
	if not target_is_valid():
		return Travel.FAILED
	var body: CharacterBody2D = wander.movement.body
	var point: Vector2 = target.access_position(target_slot)
	# A moved trough invalidates the current trip instead of feeding at a stale point.
	if not wander.destination_matches(point):
		return Travel.FAILED
	if body.global_position.distance_to(point) <= 2.0:
		wander.movement.cancel_target()
		wander.movement.stop()
		wander.animation.face(target.global_position - body.global_position)
		return Travel.ARRIVED
	if not wander.movement.has_target:
		return Travel.FAILED
	_travel_remaining -= delta
	if _travel_remaining <= 0.0:
		return Travel.FAILED
	var before: Vector2 = body.global_position
	wander.move_to_destination(delta)
	wander._keep_inside()
	var displacement: Vector2 = body.global_position - before
	wander.animation.update_facing_direction(displacement)
	wander.animation.play("walk" if not displacement.is_zero_approx() else "idle")
	return Travel.MOVING

func finish() -> float:
	return target.serve(wander.movement.body, needs, definition, target_slot) if target_is_valid() else 0.0

func cancel(failed: bool = false) -> void:
	if is_instance_valid(target):
		if failed:
			_blocked[target.get_instance_id()] = 3.0
		target.release(wander.movement.body)
	target = null
	target_slot = -1
	if wander != null:
		wander.cancel_destination()

func _exit_tree() -> void:
	cancel()

func _path_is_clear(point: Vector2) -> bool:
	if wander.traversal != null:
		return wander.traversal.can_reach(point)
	if wander.collision == null or wander.collision.shape == null:
		return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = wander.collision.shape
	query.transform = wander.collision.global_transform
	query.motion = point - wander.movement.body.global_position
	query.collision_mask = wander.movement.body.collision_mask
	query.exclude = [wander.movement.body.get_rid()]
	var fractions: PackedFloat32Array = wander.movement.body.get_world_2d().direct_space_state.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0
