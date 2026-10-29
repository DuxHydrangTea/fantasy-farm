extends GutTest
const Assignment = preload("res://components/bees/pollination_assignment.gd")

func _hive(id: String, point: Vector2, repaired: bool = true, slot: int = -1, garden: String = "") -> Dictionary:
	return {"id": id, "point": point, "repaired": repaired, "slot": slot, "garden": garden}

func test_nearest_ties_radius_and_repairs_match_the_scene_rules() -> void:
	var hives: Array[Dictionary] = [_hive("b", Vector2(3, 0)), _hive("a", Vector2(-3, 0))]
	assert_eq(Assignment.choose(Vector2.ZERO, "", -1, hives, 9.0), 1)
	assert_eq(Assignment.choose(Vector2.ZERO, "", -1, hives, 8.99), -1)
	hives[1].repaired = false
	assert_eq(Assignment.choose(Vector2.ZERO, "", -1, hives, 9.0), 0)
	assert_eq(Assignment.choose(Vector2(2, 0), "", -1, hives, 9.0), 0)

func test_fixed_garden_sources_never_leak_to_nearest_free_hive() -> void:
	var hives: Array[Dictionary] = [_hive("free", Vector2.ZERO), _hive("fixed", Vector2(100, 0), true, 2, "garden")]
	assert_eq(Assignment.choose(Vector2.ZERO, "garden", 2, hives, 1.0), 1)
	assert_eq(Assignment.choose(Vector2.ZERO, "other", 2, hives, 1.0), -1)
	assert_eq(Assignment.choose(Vector2.ZERO, "", -1, hives, 1.0), 0)
	hives[1].repaired = false
	assert_eq(Assignment.choose(Vector2.ZERO, "garden", 2, hives, 1.0), -1)
