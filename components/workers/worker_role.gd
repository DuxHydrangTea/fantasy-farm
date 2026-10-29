class_name WorkerRole
extends RefCounted
## Pure policy: deterministic priority, distance, then stable target ID.
const ROLES: Array[String] = ["orchard", "ranch", "crop"]
const LIMITS: Dictionary = {"orchard": 1, "ranch": 1, "crop": 5}
const WAGES: Dictionary = {"orchard": 1800, "ranch": 2200, "crop": 2800}
static func point(coordinates: Array) -> Vector2:
	return Vector2(float(coordinates[0]), float(coordinates[1]))

static func pair(value: Vector2) -> Array:
	return [value.x, value.y]

static func choose(candidates: Array[Dictionary], origin: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = INF
	for task: Dictionary in candidates:
		var next_distance: float = origin.distance_squared_to(point(task.point))
		if best.is_empty() or int(task.priority) < int(best.priority) or (int(task.priority) == int(best.priority) and (next_distance < distance or (is_equal_approx(next_distance, distance) and String(task.id) < String(best.id)))):
			best = task
			distance = next_distance
	return best.duplicate(true)

static func target_key(job: Dictionary) -> String:
	if job.is_empty() or job.get("kind", "") == "patrol":
		return ""
	if job.kind == "pickup":
		return "pickup:" + String(job.get("id", ""))
	if job.has("cell"):
		return "cell:%d_%d" % [int(job.cell[0]), int(job.cell[1])]
	return "station:" + String(job.get("id", ""))
