extends RefCounted
## Pure geometry: no Nodes, clock, inventory or rendering access.
static func choose(point: Vector2, garden: String, fixed_slot: int, hives: Array[Dictionary], radius_squared: float) -> int:
	var nearest: int = -1
	var distance: float = INF
	for index: int in range(hives.size()):
		var hive: Dictionary = hives[index]
		if not hive.repaired:
			continue
		if fixed_slot >= 0 or int(hive.slot) >= 0:
			if fixed_slot == int(hive.slot) and garden == String(hive.garden):
				return index
			continue
		var candidate: float = (hive.point as Vector2).distance_squared_to(point)
		if candidate <= radius_squared and (candidate < distance or (is_equal_approx(candidate, distance) and (nearest < 0 or String(hive.id) < String(hives[nearest].id)))):
			nearest = index
			distance = candidate
	return nearest
