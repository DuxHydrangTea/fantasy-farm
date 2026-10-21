class_name PollinationComponent
extends RefCounted
## One flower belongs to one nearest hive. This view chooses the dominant species.
var sources: Array[Dictionary] = []
var source_id: String = ""
var source_name: String = ""
var source_point: Vector2
var source_count: int = 0

func resolve(origin: Vector2) -> void:
	source_id = ""
	source_name = ""
	source_count = 0
	var counts: Dictionary = {}
	var closest: Dictionary = {}
	for source: Dictionary in sources:
		var key: String = source.type
		counts[key] = int(counts.get(key,0)) + 1
		if not closest.has(key) or origin.distance_squared_to(source.point) < origin.distance_squared_to(closest[key].point):
			closest[key] = source
	var distance: float = INF
	for key: String in counts:
		var candidate: float = origin.distance_squared_to(closest[key].point)
		if int(counts[key]) > source_count or (int(counts[key]) == source_count and (candidate < distance or (is_equal_approx(candidate,distance) and key < source_id))):
			source_id = key
			source_name = closest[key].name
			source_point = closest[key].point
			source_count = int(counts[key])
			distance = candidate

func active() -> bool:
	return not source_id.is_empty()
