extends GutTest
const Growth = preload("res://components/animals/animal_growth_component.gd")
var growth: Growth

func before_each() -> void:
	growth = Growth.new()
	add_child_autofree(growth)
	growth.configure(10.0)

func test_age_progress_and_one_maturity_signal() -> void:
	watch_signals(growth)
	growth.advance(4.0)
	assert_eq(growth.age_seconds, 4.0)
	assert_eq(growth.progress_ratio(), 0.4)
	assert_eq(growth.seconds_until_adult(), 6.0)
	assert_false(growth.is_adult())
	growth.advance(6.0)
	assert_true(growth.is_adult())
	growth.advance(100.0)
	assert_eq(growth.progress_ratio(), 1.0)
	assert_signal_emit_count(growth, "matured", 1)

func test_initial_age_and_instant_maturity() -> void:
	growth.configure(10.0, 20.0)
	assert_true(growth.is_adult())
	assert_eq(growth.seconds_until_adult(), 0.0)
	growth.configure(0.0)
	assert_true(growth.is_adult())
	assert_eq(growth.progress_ratio(), 1.0)

func test_negative_elapsed_and_initial_values_never_reverse_age() -> void:
	growth.configure(-1.0, -5.0)
	assert_eq(growth.age_seconds, 0.0)
	assert_eq(growth.maturity_seconds, 0.0)
	growth.advance(5.0)
	growth.advance(-10.0)
	assert_eq(growth.age_seconds, 5.0)

func test_animals_do_not_share_age_state() -> void:
	var other: Growth = Growth.new()
	add_child_autofree(other)
	other.configure(10.0)
	growth.advance(20.0)
	assert_true(growth.is_adult())
	assert_false(other.is_adult())
