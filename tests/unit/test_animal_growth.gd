extends GutTest
var growth: AnimalGrowthComponent

func before_each() -> void:
	growth = AnimalGrowthComponent.new()
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
	var other: AnimalGrowthComponent = AnimalGrowthComponent.new()
	add_child_autofree(other)
	other.configure(10.0)
	growth.advance(20.0)
	assert_true(growth.is_adult())
	assert_false(other.is_adult())

func test_lifetime_boundary_caps_age_and_emits_once_even_after_large_offline_jump() -> void:
	growth.configure(10.0, 0.0, 20.0)
	watch_signals(growth)
	growth.advance(19.0)
	assert_false(growth.is_dead())
	assert_eq(growth.seconds_until_death(), 1.0)
	growth.advance(1000.0)
	assert_true(growth.is_dead())
	assert_eq(growth.age_seconds, 20.0)
	assert_eq(growth.seconds_until_death(), 0.0)
	growth.advance(1000.0)
	assert_signal_emit_count(growth, "matured", 1)
	assert_signal_emit_count(growth, "lifespan_reached", 1)

func test_all_species_use_one_real_day_to_mature_and_fourteen_days_total_lifetime() -> void:
	for species: String in ["chicken", "cow", "sheep", "duck", "goose", "pig", "horse"]:
		var data: AnimalDefinition = load("res://animals/definitions/" + species + ".tres") as AnimalDefinition
		assert_true(data.is_valid())
		assert_eq(data.maturity_seconds, 86400.0, species)
		assert_eq(data.lifespan_seconds, 1209600.0, species)
		growth.configure(data.maturity_seconds, 0.0, data.lifespan_seconds)
		growth.advance(86399.0)
		assert_false(growth.is_adult())
		growth.advance(1.0)
		assert_true(growth.is_adult())
		growth.advance(13.0 * 86400.0 - 1.0)
		assert_false(growth.is_dead())
		growth.advance(1.0)
		assert_true(growth.is_dead())
