class_name WorkerBehaviourComponent
extends Node
## M0: waypoint patrol only — role task scan/work arrives in M1+.
## Keeps its own goal across MovementComponent's 0.2s blocked auto-cancel
## (see movement_component.gd): a blocked target is re-issued every frame
## until `stuck_seconds` elapses, then skipped for the next waypoint.
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
	movement.move_to_target(delta)
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
	var row: Dictionary = actor.worker_service.record_for(String(actor.persistent_id))
	if row.is_empty():
		return
	_badge_elapsed += delta
	if _badge_elapsed >= 0.25:
		_badge_elapsed = 0.0
		_update_badge(actor, row)
	if not actor.worker_service.running(row):
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		return
	var task: Dictionary = row.task
	if task.is_empty():
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		return
	var goal: Vector2 = WorkerRole.point(task.point)
	if actor.global_position.distance_to(goal) <= movement.arrival_distance:
		movement.cancel_target()
		movement.stop()
		animation.play("idle")
		if float(task.get("arrived_at", -1.0)) < 0.0:
			var now: float = actor.worker_service.world.farming.time_manager.now()
			task["arrived_at"] = now
			task.work_at = maxf(float(task.work_at), now)
			task.finish_at = maxf(float(task.finish_at), float(task.work_at) + actor.definition.work_seconds)
		_blocked_elapsed = 0.0
		return
	if not movement.has_target or not movement.target_position.is_equal_approx(goal):
		movement.set_target(goal)
	var before: Vector2 = actor.global_position
	movement.move_to_target(delta)
	var displacement: Vector2 = actor.global_position - before
	animation.update_facing_direction(displacement)
	animation.play("walk" if displacement.length_squared() > 0.000001 else "idle")
	_blocked_elapsed = _blocked_elapsed + delta if displacement.length_squared() < 0.000001 else 0.0
	if _blocked_elapsed >= stuck_seconds:
		actor.worker_service.blocked(String(actor.persistent_id), actor.worker_service.world.farming.time_manager.now())
		movement.cancel_target()
		_blocked_elapsed = 0.0

func _update_badge(actor: WorkerActor, row: Dictionary) -> void:
	var used: int = 0
	for i: int in range(actor.basket.slot_count):
		used += 0 if actor.basket.is_empty_slot(i) else 1
	actor.badge.text = (tr("Crop worker #{number}").format({"number": actor.worker_service.worker_number(String(actor.persistent_id))}) + "\n" if actor.worker_role == "crop" else "") + tr("Products → Warehouse")
	if actor.worker_role == "crop" and (row.task.is_empty() or row.task.kind == "patrol"):
		actor.badge.text += "\n" + tr(actor.worker_service.crop_policy.waiting)
	if used > 0:
		actor.badge.text += "\n" + tr("Basket %d/16") % used
	if bool(actor.worker_service.bridge.storage_waiting.get(actor.worker_role, false)):
		actor.badge.text += "\n" + tr("Warehouse needs space")
	if not actor.worker_service.running(row):
		actor.badge.text += "\n" + tr("Resting")
	elif not row.task.is_empty():
		actor.badge.text += "\n" + tr(String(row.task.kind))
