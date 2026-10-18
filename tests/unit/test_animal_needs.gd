extends GutTest
const Clock = preload("res://components/time_manager.gd")
const Needs = preload("res://components/animals/animal_needs_component.gd")
var timestamp: float = 1000.0
var clock: Clock
var needs: Needs

func before_each() -> void:
	timestamp = 1000.0
	clock = Clock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	needs = Needs.new()
	needs.time_manager = clock
	add_child_autofree(needs)
	needs.configure(600.0, 300.0)

func test_food_and_water_deplete_independently_from_timestamps() -> void:
	timestamp += 150.0
	clock.refresh()
	assert_almost_eq(needs.satiety, 75.0, 0.001)
	assert_almost_eq(needs.hydration, 50.0, 0.001)

func test_large_jump_clamps_to_zero_and_does_not_emit_again() -> void:
	watch_signals(needs)
	needs.update_at(10000.0)
	assert_eq(needs.satiety, 0.0)
	assert_eq(needs.hydration, 0.0)
	needs.update_at(20000.0)
	assert_signal_emit_count(needs, "changed", 1)

func test_feed_drink_cap_and_return_actual_restored_amount() -> void:
	timestamp += 150.0
	assert_eq(needs.feed(100.0), 25.0)
	assert_eq(needs.hydration, 50.0)
	assert_eq(needs.drink(20.0), 20.0)
	assert_eq(needs.hydration, 70.0)
	assert_eq(needs.feed(-5.0), 0.0)
	assert_eq(needs.drink(-5.0), 0.0)
	assert_eq(needs.drink(1000.0), 30.0)
	assert_eq(needs.satiety, 100.0)
	assert_eq(needs.hydration, 100.0)

func test_repeated_or_backward_timestamp_does_not_double_charge() -> void:
	needs.update_at(1100.0)
	var before: Vector2 = Vector2(needs.satiety, needs.hydration)
	needs.update_at(1100.0)
	needs.update_at(1000.0)
	assert_eq(Vector2(needs.satiety, needs.hydration), before)
	needs.update_at(1150.0)
	assert_almost_eq(needs.satiety, 75.0, 0.001)

func test_needs_of_two_animals_do_not_share_state() -> void:
	var other: Needs = Needs.new()
	other.time_manager = clock
	add_child_autofree(other)
	needs.update_at(1300.0)
	assert_eq(other.satiety, 100.0)
	assert_eq(other.hydration, 100.0)
