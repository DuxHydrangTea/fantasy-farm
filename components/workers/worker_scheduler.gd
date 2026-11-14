class_name WorkerScheduler
extends RefCounted
## Advances the worker timeline and owns its frame budget and resume cursor.

const ONLINE_BUDGET_USEC: int = 2000
var _event_open: bool = false
var _event_row: int = 0
var _budget_frame: int = -1
var _budget_spent_usec: int = 0
var _online_pending: bool = false

func reset_checkpoint() -> void:
	_event_open = false
	_event_row = 0
	_online_pending = false

func before_tick(team: WorkerService, timestamp: float) -> void:
	if not team.available() or team.records.is_empty() or timestamp - team.simulated_at < 0.25:
		return
	# Catch up workers before other world systems consume this same time span.
	var offline: bool = timestamp - team.simulated_at > 5.0 and not _event_open
	if offline:
		team.advance(timestamp, true)
	else:
		advance_online(team, timestamp)

func advance_online(team: WorkerService, timestamp: float) -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_spent_usec = 0
	var remaining: int = ONLINE_BUDGET_USEC - _budget_spent_usec
	if remaining <= 0:
		return
	var started: int = Time.get_ticks_usec()
	_online_pending = not team.advance(timestamp, false, remaining)
	_budget_spent_usec += Time.get_ticks_usec() - started
	if team.profiling:
		team.scheduler_usec += Time.get_ticks_usec() - started

func has_pending_work() -> bool:
	return _event_open or _online_pending

## A budget can pause between events or at a worker within an open event.
## The next call resumes at that event and worker, even at the requested endpoint.
func advance(team: WorkerService, clock: FarmClock, weather: WeatherSchedule, until: float, offline: bool, budget_usec: int, started: int) -> bool:
	if not _event_open:
		team.records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hire_order) < int(b.hire_order))
	while team.simulated_at <= until:
		clock.simulation_timestamp = team.simulated_at
		if not _event_open:
			team.prepare_simulation_event(offline)
			_event_row = 0
			_event_open = true
		var day: int = weather.day_at(team.simulated_at)
		for index: int in range(_event_row, team.records.size()):
			if not offline and budget_usec > 0 and index > _event_row and Time.get_ticks_usec() - started >= budget_usec:
				_event_row = index
				return false
			if not _advance_worker(team, team.records[index], day, offline):
				_event_row = index
				return false
		_event_open = false
		_event_row = 0
		if team.simulated_at >= until:
			break
		var next: float = minf(until, weather.dawn_at(day + 1))
		for row: Dictionary in team.records:
			if team.running(row):
				next = minf(next, float(row.task.finish_at) if not row.task.is_empty() else float(row.wake_at))
				if not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"]:
					next = minf(next, team.bridge.next_wake(row, team.feed_inventory(row.id), team.simulated_at))
		team.simulated_at = minf(until, maxf(team.simulated_at + 0.00001, next))
		if budget_usec > 0 and Time.get_ticks_usec() - started >= budget_usec:
			return false
	return true

func _advance_worker(team: WorkerService, row: Dictionary, day: int, offline: bool) -> bool:
	team.pay_daily_wage(row, day)
	if not team.running(row):
		return true
	var actor: WorkerActor = team.actors[row.id] as WorkerActor
	if not row.task.is_empty() and row.task.kind == "cure_animal":
		if not team.bridge.refresh_animal_task(row, offline):
			row.task = {}
			row.wake_at = team.simulated_at + 0.5
	# Animal demand can arise while travelling to a lower-priority plot.
	# Keep prepared soil; an interrupted job has not spent its supplies.
	if not row.task.is_empty() and row.task.kind in ["till", "plant", "fertilize"] and float(row.task.finish_at) > team.simulated_at:
		var urgent_held: Dictionary = team.reservations(String(row.id))
		for option: Dictionary in team.bridge.ranch_candidates(row, team.feed_inventory(row.id), urgent_held):
			if float(team.blocked_targets.get(String(row.id) + ":" + String(option.id), 0)) <= team.simulated_at:
				row.position = WorkerRole.pair(actor.global_position)
				row.task = {}
				row.wake_at = team.simulated_at
				break
	_finish_due_task(team, row, actor, offline)
	if row.task.is_empty() and float(row.wake_at) <= team.simulated_at:
		return _assign_task(team, row, actor, offline)
	return true

func _finish_due_task(team: WorkerService, row: Dictionary, actor: WorkerActor, offline: bool) -> void:
	var task: Dictionary = row.task
	if not task.is_empty() and float(task.finish_at) <= team.simulated_at + 0.00001:
		var target: Vector2 = WorkerRole.point(task.point)
		if not offline and actor.global_position.distance_to(target) > 3.0:
			task.finish_at = team.simulated_at + 0.25
		else:
			row.position = task.point.duplicate()
			if offline:
				actor.global_position = target
			var commit_started: int = Time.get_ticks_usec() if team.profiling else 0
			if task.has("cells"):
				WorkerAreaPolicy.commit_next(team, row, task)
			else:
				team.bridge.commit(row, team.feed_inventory(row.id), task)
			if team.profiling:
				var spent: int = Time.get_ticks_usec() - commit_started
				team.commit_usec += spent
				team.commit_max_usec = maxi(team.commit_max_usec, spent)
			if task.has("cells") and int(task.cursor) < task.cells.size():
				task.finish_at = team.simulated_at + 0.00001
			else:
				row.task = {}
				row.wake_at = team.simulated_at + (team.bridge.rest_seconds(row) if String(task.get("kind", "")) == "patrol" else 0.0)

func _assign_task(team: WorkerService, row: Dictionary, actor: WorkerActor, offline: bool) -> bool:
	if not offline:
		row.position = WorkerRole.pair(actor.global_position)
	# Full crop/plant scan is exclusively for workers that need a task.
	var held: Dictionary = team.reservations(String(row.id))
	team.crop_policy.query_pending = false
	var candidates: Array[Dictionary] = team.bridge.candidates(row, team.feed_inventory(row.id))
	if team.crop_policy.query_pending:
		return false
	var chosen: Dictionary = _choose_task(team, row, candidates, held)
	var wake: float = team.bridge.next_wake(row, team.feed_inventory(row.id), team.simulated_at)
	if chosen.is_empty():
		var stroll: Vector2 = team.bridge.patrol_point(row)
		chosen = {"kind": "patrol", "id": "patrol:%d_%d" % [roundi(stroll.x), roundi(stroll.y)], "point": WorkerRole.pair(stroll), "priority": 9}
	if not chosen.is_empty() and (String(chosen.get("kind", "")) == "patrol" or team.bridge.zone_contains(row, WorkerRole.point(chosen.point))):
		WorkerAreaPolicy.expand(team, row, chosen)
		chosen["duration"] = team.upgrades.duration(actor.definition.work_seconds, String(chosen.kind))
		chosen["base_point"] = chosen.point.duplicate()
		chosen["attempt"] = 0
		chosen["work_at"] = team.simulated_at + WorkerRole.point(row.position).distance_to(WorkerRole.point(chosen.point)) / actor.movement.speed + actor.movement.speed / actor.movement.acceleration
		chosen["finish_at"] = chosen.work_at + team.task_duration(chosen, actor)
		if chosen.kind == "patrol":
			chosen.finish_at = maxf(float(chosen.finish_at), minf(team.simulated_at + 60.0, wake))
		row.task = chosen
	else:
		row.wake_at = team.bridge.next_wake(row, team.feed_inventory(row.id), team.simulated_at)
	return true

func _choose_task(team: WorkerService, row: Dictionary, candidates: Array[Dictionary], held: Dictionary) -> Dictionary:
	var worker_id: String = String(row.id)
	var options: Array[Dictionary] = []
	for option: Dictionary in candidates:
		if option.has("cell") and held.cells.has(Vector2i(int(option.cell[0]), int(option.cell[1]))):
			continue
		if held.targets.has(team.target_key(option)):
			continue
		var blocked_until: float = float(team.blocked_targets.get(worker_id + ":" + String(option.id), 0))
		if blocked_until <= team.simulated_at and team.bridge.zone_contains(row, WorkerRole.point(option.point)):
			options.append(option)
	WorkerRole.apply_priorities(options, team.crop_automation.priority_mode)
	if options.is_empty() and not candidates.is_empty() and not team.waiting_reasons.has(worker_id):
		team.waiting_reasons[worker_id] = "Work targets are reserved or blocked. Waiting for another opportunity."
	return WorkerRole.choose(options, WorkerRole.point(row.position))

