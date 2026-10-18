extends GutTest
const Pen = preload("res://components/animals/animal_pen.gd")
var pen: Pen

func before_each() -> void:
	pen = Pen.new()
	pen.bounds = Rect2(-20, -10, 200, 100)
	add_child_autofree(pen)

func test_samples_and_clamps_respect_translated_scaled_rotated_pen() -> void:
	pen.position = Vector2(230, 90)
	pen.scale = Vector2(2, 1.5)
	pen.rotation = 0.4
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73
	for index: int in range(300):
		assert_true(pen.contains_world(pen.sample_world(rng, 12.0), 12.0))
		var outside: Vector2 = pen.to_global(Vector2(-500, 500))
		assert_true(pen.contains_world(pen.clamp_world(outside, 12.0), 12.0))
	assert_false(pen.contains_world(pen.to_global(Vector2(-100, 0))))

func test_oversized_margin_collapses_to_center_without_invalid_targets() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_eq(pen.sample_world(rng, 1000.0), pen.to_global(pen.bounds.get_center()))
	assert_eq(pen.clamp_world(Vector2(-999, -999), 1000.0), pen.to_global(pen.bounds.get_center()))
