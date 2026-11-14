class_name WorkerBehaviourComponent
extends Node
## Follows service tasks with shared navigation and handles standalone patrols.
@export var movement: MovementComponent
@export var animation: AnimationComponent
var patrol_points: Array[Vector2] = []
var patrol_wait_seconds: float = 0.6
var stuck_seconds: float = 2.0
var current_goal: Vector2 = Vector2.ZERO
var has_goal: bool = false
var waypoint_index: int = 0
var _blocked_elapsed: float = 0.0
var _wait_remaining: float = 0.0
var _badge_elapsed: float = 1.0
var _navigation: WorkerNavigation
var _care_target: WeakRef
var _path_to_work_point: bool = false

func _exit_tree() -> void:
	_release_care_target()

func _release_care_target() -> void:
	var animal: AnimalActor = _care_target.get_ref() as AnimalActor if _care_target != null else null
	if is_instance_valid(animal) and is_instance_valid(animal.behaviour):
		animal.behaviour.release_care_hold(self)
	_care_target = null

func _care_focus_active() -> bool:
	var actor: WorkerActor = movement.body as WorkerActor
	var animal: AnimalActor = _care_target.get_ref() as AnimalActor if _care_target != null else null
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not is_instance_valid(actor.worker_service) or not is_instance_valid(animal) or animal.is_queued_for_deletion() or animal.is_dead() or not animal.health.sick:
		return false
	var row: Dictionary = actor.worker_service.record_for(String(actor.persistent_id))
	return not row.is_empty() and actor.worker_service.running(row) and row.task.get("kind", "") == "cure_animal" and String(row.task.get("id", "")) == String(animal.persistent_id)

func _sync_care_target(actor: WorkerActor, row: Dictionary) -> void:
	var desired: AnimalActor
	if not row.is_empty() and actor.worker_service.running(row) and row.task.get("kind", "") == "cure_animal":
		desired = actor.worker_service.bridge.animal_for(String(row.task.id))
		if is_instance_valid(desired) and (desired.is_dead() or not desired.health.sick):
			desired = null
	var current: AnimalActor = _care_target.get_ref() as AnimalActor if _care_target != null else null
	if desired == current:
		if is_instance_valid(desired):
			desired.behaviour.hold_for_care(self, _care_focus_active)
		return
	_release_care_target()
	if is_instance_valid(desired):
		_care_target = weakref(desired)
		desired.behaviour.hold_for_care(self, _care_focus_active)

func _request_navigation(actor: WorkerActor, goal: Vector2) -> void:
	if _navigation == null:
		_navigation = WorkerNavigation.new()
		_navigation.system = actor.worker_service.navigation
		_navigation.movement = movement
		_navigation.animation = animation
		_navigation.camera = actor.worker_service.world.player.camera
		_navigation.collision_shape = actor.collision
		_navigation.sampling_budget = 96
		# Arbitrary world points can be up to 5.7 px from an 8 px grid node.
		# Leave room for the movement arrival tolerance; the final approach below
		# still brings the worker to within 2 px of the actual work point.
		_navigation.interaction_distance = 12.0
		_navigation.allow_focus_cell = true
		add_child(_navigation)
		_navigation.set_physics_process(false)
		_navigation.focus_finished.connect(func(reached: bool) -> void:
			if not reached:
				actor.worker_service.blocked(String(actor.persistent_id), actor.worker_service.world.farming.time_manager.now()))
	if not _navigation.has_focus or not _navigation.focus_position.is_equal_approx(goal) or _navigation.exact_goal != _path_to_work_point:
		_navigation.request_worker_goal(goal, _path_to_work_point)

func _navigate(actor: WorkerActor, goal: Vector2, delta: float) -> void:
	_request_navigation(actor, goal)
	var before: Vector2 = actor.global_position
	_navigation.move(delta)
	animation.play("walk" if actor.global_position.distance_squared_to(before) > 0.000001 else "idle")

func _physics_process(delta: float) -> void:
	_step(delta)

func _step(delta: float) -> void:
	var actor: WorkerActor = movement.body as WorkerActor
	if actor != null and actor.worker_service != null:
		_step_work(actor, delta)
		return
	if patrol_points.is_empty():
		animation.play("idle")
		return
	if not movement.has_target:
		movement.stop()
		if has_goal:
			# MovementComponent cancelled (arrival or 0.2s blocked). Arrival is
			# indistinguishable from a block here, so only the stuck budget
			# decides between "keep pushing" and "skip the waypoint".
			if _blocked_elapsed < stuck_seconds and not _arrived():
				movement.set_target(current_goal)
				return
			has_goal = false
			_blocked_elapsed = 0.0
			_wait_remaining = patrol_wait_seconds
		animation.play("idle")
		_wait_remaining -= delta
		if _wait_remaining <= 0.0:
			_advance_waypoint()
		return
	var before: Vector2 = movement.body.global_position
	movement.move_to_target(delta, true)
	var displacement: Vector2 = movement.body.global_position - before
	animation.update_facing_direction(displacement)
	animation.play("idle" if displacement.is_zero_approx() else "walk")
	if displacement.length_squared() < 0.000001:
		_blocked_elapsed += delta
	else:
		_blocked_elapsed = 0.0

func _arrived() -> bool:
	return movement.body.global_position.distance_to(current_goal) <= movement.arrival_distance

func _advance_waypoint() -> void:
	waypoint_index = (waypoint_index + 1) % patrol_points.size()
	current_goal = patrol_points[waypoint_index]
	has_goal = true
	_blocked_elapsed = 0.0
	_wait_remaining = 0.0
	movement.set_target(current_goal)

func begin_patrol(at: Vector2) -> void:
	if patrol_points.is_empty():
		return
	var nearest: int = 0
	var best: float = -1.0
	for index: int in range(patrol_points.size()):
		var distance: float = at.distance_to(patrol_points[index])
		if best < 0.0 or distance < best:
			best = distance
			nearest = index
	waypoint_index = nearest
	current_goal = patrol_points[waypoint_index]
	has_goal = true
	movement.set_target(current_goal)

func _step_work(actor: WorkerActor, delta: float) -> void:
	if actor.care_action != null:
		actor.care_action.show_action("", Vector2.ZERO)
	var row: Dictionary = actor.worker_service.record_for(String(actor.persistent_id))
	_sync_care_target(actor, row)
	if row.is_empty():
		return
	_badge_elapsed += delta
	if _badge_elapsed >= 0.25:
		_badge_elapsed = 0.0
		_update_badge(actor, row)
	if not actor.worker_service.running(row):
		_path_to_work_point = false
		if _navigation != null and _navigation.has_focus:
			_navigation.cancel()
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		return
	var task: Dictionary = row.task
	if task.is_empty():
		_path_to_work_point = false
		if _navigation != null and _navigation.has_focus:
			_navigation.cancel()
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		return
	var goal: Vector2 = WorkerRole.point(task.point)
	var distance: float = actor.global_position.distance_to(goal)
	if _path_to_work_point and (_navigation == null or not _navigation.focus_position.is_equal_approx(goal)):
		_path_to_work_point = false
	if distance > 12.0 or (_path_to_work_point and distance > movement.arrival_distance):
		_navigate(actor, goal, delta)
		return
	if _navigation != null and _navigation.has_focus:
		_navigation.cancel()
	if distance <= movement.arrival_distance:
		_path_to_work_point = false
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		if float(task.get("arrived_at", -1.0)) < 0.0:
			var now: float = actor.worker_service.world.farming.time_manager.now()
			task["arrived_at"] = now
			task.work_at = maxf(float(task.work_at), now)
			task.finish_at = maxf(float(task.finish_at), float(task.work_at) + actor.worker_service.task_duration(task, actor))
		if task.kind in ["treat_pests", "treat_weeds", "cure_animal"] and actor.care_action != null:
			var direction: Vector2 = animation.facing_vector
			if task.kind == "cure_animal":
				var animal: AnimalActor = actor.worker_service.bridge.animal_for(String(task.id))
				if animal != null:
					direction = animal.global_position - actor.global_position
					animation.face(direction)
			actor.care_action.show_action(String(task.kind), direction)
		_blocked_elapsed = 0.0
		return
	if not movement.has_target or not movement.target_position.is_equal_approx(goal):
		movement.set_target(goal)
	var before: Vector2 = actor.global_position
	movement.move_to_target(delta)
	var displacement: Vector2 = actor.global_position - before
	animation.update_facing_direction(displacement)
	animation.play("walk" if displacement.length_squared() > 0.000001 else "idle")
	if not movement.has_target and actor.global_position.distance_to(goal) > movement.arrival_distance:
		_path_to_work_point = true
		_request_navigation(actor, goal)

func _update_badge(actor: WorkerActor, row: Dictionary) -> void:
	var kind: String = String(row.task.get("kind", ""))
	var icon: Texture2D
	if actor.worker_service.running(row):
		match kind:
			"treat_weeds": icon = preload("res://items/boosters/herbicide.tres").icon
			"treat_pests": icon = preload("res://items/boosters/pesticide.tres").icon
			"cure_animal": icon = preload("res://items/boosters/animal_medicine.tres").icon
			"water_crop", "water_trough", "fetch_water": icon = preload("res://items/tools/watering_can.tres").icon
			"till": icon = preload("res://items/tools/hoe.tres").icon
			"plant": icon = preload("res://items/seeds/carrot_seed.tres").icon
			"fertilize": icon = preload("res://items/boosters/crop_fertilizer.tres").icon
			"feed": icon = preload("res://items/feeds/livestock_feed.tres").icon
			"harvest", "fruit", "pickup": icon = preload("res://crops/field/wheat/wheat.tres").harvest_item.icon
	var attention: bool = not actor.worker_service.running(row) or ((kind.is_empty() or kind == "patrol") and actor.worker_service.waiting_reasons.has(String(row.id)))
	actor.show_status(actor.worker_service.worker_number(String(actor.persistent_id)), icon, attention)
