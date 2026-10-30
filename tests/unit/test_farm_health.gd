extends GutTest
const Conditions = preload("res://components/crop_condition_state.gd")
const Health = preload("res://components/animals/animal_health_state.gd")

func test_crop_flags_are_independent_and_checked_once() -> void:
	var state: Conditions = Conditions.new()
	state.pest_roll = 0.0
	state.weed_roll = 0.0
	state.advance(0.32)
	assert_false(state.affected())
	state.advance(1.0 / 3.0)
	assert_true(state.pests)
	assert_false(state.weeds)
	state.pests = false
	state.advance(2.0 / 3.0)
	assert_false(state.pests, "No reinfection after treatment")
	assert_true(state.weeds)
	state.advance(0.1)
	assert_true(state.weeds, "A backward timestamp cannot undo an event")

func test_all_crop_combinations_and_multiplicative_yield() -> void:
	var state: Conditions = Conditions.new()
	for flags: Array in [[false, false, 1.0], [true, false, 0.8], [false, true, 0.85], [true, true, 0.68]]:
		state.pests = flags[0]
		state.weeds = flags[1]
		assert_almost_eq(state.multiplier(), float(flags[2]), 0.00001)

func test_fixed_fractional_rounding_can_produce_zero_without_rerolls() -> void:
	var state: Conditions = Conditions.new()
	state.pests = true
	state.yield_roll = 0.9
	for i: int in range(20):
		assert_eq(state.amount(1), 0)
	var restored: Conditions = Conditions.new()
	restored.restore(state.capture())
	assert_eq(restored.amount(1), 0)
	state.pests = false
	assert_eq(state.amount(1), 1, "Curing never makes yield worse")

func test_crop_jump_and_many_small_steps_match() -> void:
	var small: Conditions = Conditions.new()
	small.pest_roll = 0.05
	small.weed_roll = 0.05
	var jump: Conditions = Conditions.new()
	jump.restore(small.capture())
	for i: int in range(101):
		small.advance(i / 100.0)
	jump.advance(1.0)
	assert_eq_deep(small.capture(), jump.capture())

func test_condition_validation_and_clean_legacy_crop() -> void:
	assert_true(Conditions.valid(Conditions.legacy()))
	var data: Dictionary = Conditions.legacy()
	data.yield_roll = NAN
	assert_false(Conditions.valid(data))
	data = Conditions.legacy()
	data.pest_checked = false
	data.pests = true
	assert_false(Conditions.valid(data))
	var state: Conditions = Conditions.new()
	state.restore(Conditions.legacy())
	state.advance(1.0)
	assert_false(state.affected())

func test_disease_splits_production_at_exact_onset() -> void:
	var health: Health = Health.new()
	health.next_onset_at = 30.0
	assert_eq(health.advance(0, 60, 0, 60), 45.0)
	assert_true(health.sick)
	assert_eq(health.advance(60, 120, 60, 120), 30.0)

func test_disease_intersects_food_maturity_and_lifetime() -> void:
	var health: Health = Health.new()
	health.next_onset_at = 30.0
	assert_eq(health.advance(0, 100, 20, 40), 15.0)
	assert_true(health.sick)
	assert_eq(health.advance(100, 200, 150, 110), 0.0)
	assert_true(health.sick, "Starvation does not cure disease")

func test_health_jump_and_many_small_steps_match() -> void:
	var small: Health = Health.new()
	small.configure(0, 10, 12345)
	var jump: Health = Health.new()
	jump.restore(small.capture())
	var total: float = 0.0
	for i: int in range(1000):
		total += small.advance(i * 100.0, (i + 1) * 100.0, 10, 80000)
	assert_almost_eq(total, jump.advance(0, 100000, 10, 80000), 0.001)
	assert_eq_deep(small.capture(), jump.capture())

func test_cure_is_independent_protects_and_does_not_reroll_when_healthy() -> void:
	var health: Health = Health.new()
	health.configure(100, 20, 17)
	var before: Dictionary = health.capture()
	assert_false(health.cure(100))
	assert_eq_deep(health.capture(), before)
	health.sick = true
	assert_true(health.cure(300))
	assert_false(health.sick)
	assert_gt(health.next_onset_at, 600.0)
	assert_true(Health.valid(health.capture()))

func test_health_rng_persists_and_invalid_values_are_rejected() -> void:
	var first: Health = Health.new()
	first.configure(1000, 10, 42)
	var second: Health = Health.new()
	second.restore(first.capture())
	first.sick = true
	second.sick = true
	first.cure(2000)
	second.cure(2000)
	assert_eq_deep(first.capture(), second.capture())
	var bad: Dictionary = first.capture()
	bad.rng_state = 0
	assert_false(Health.valid(bad))
	bad = first.capture()
	bad.next_onset_at = INF
	assert_false(Health.valid(bad))
