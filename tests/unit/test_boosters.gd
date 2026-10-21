extends GutTest
const CROP: PackedScene = preload("res://scenes/crops/crop.tscn")
var crop: Crop
var growth: AnimalGrowthComponent
var production: AnimalProductionComponent

func before_each() -> void:
	crop = CROP.instantiate() as Crop
	add_child_autofree(crop)
	var data: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	data.growth_seconds = 100.0
	crop.configure(data, 1000.0)
	growth = AnimalGrowthComponent.new()
	add_child_autofree(growth)
	growth.configure(86400.0, 3600.0, 1209600.0)
	production = AnimalProductionComponent.new()
	add_child_autofree(production)
	var output: AnimalProductionDefinition = load("res://animals/productions/chicken_egg_production.tres").duplicate() as AnimalProductionDefinition
	output.production_seconds = 10.0
	output.production_amount = 1
	production.configure(output)

func test_fertilizer_uses_original_duration_once_and_resets_for_new_lifecycle() -> void:
	assert_true(crop.apply_fertilizer(1049.0))
	assert_eq(crop.matures_at, 1080.0)
	assert_almost_eq(crop.progress, 49.0 / 80.0, 0.00001)
	assert_false(crop.apply_fertilizer(1049.0))
	crop.refresh(1080.0)
	assert_true(crop.is_mature())
	crop.configure(crop.definition, 2000.0)
	assert_false(crop.fertilized)
	assert_true(crop.apply_fertilizer(2000.0))
	assert_eq(crop.matures_at, 2080.0)

func test_exact_half_and_later_progress_reject_without_shortening_deadline() -> void:
	assert_false(crop.apply_fertilizer(1050.0))
	assert_eq(crop.matures_at, 1100.0)
	assert_false(crop.fertilized)
	assert_false(crop.apply_fertilizer(1100.0))

func test_juvenile_tonic_halves_maturity_without_changing_age_or_lifetime() -> void:
	assert_true(growth.apply_juvenile_tonic())
	assert_eq(growth.maturity_seconds, 43200.0)
	assert_eq(growth.age_seconds, 3600.0)
	assert_eq(growth.seconds_until_death(), 1206000.0)
	assert_false(growth.apply_juvenile_tonic())
	growth.advance(39600.0)
	assert_true(growth.is_adult())
	assert_eq(growth.seconds_until_death(), 1166400.0)
	growth.configure(86400.0, 3600.0, 1209600.0, true)
	assert_eq(growth.maturity_seconds, 43200.0)
	assert_false(growth.apply_juvenile_tonic())

func test_late_juvenile_dose_matures_now_and_never_resurrects_dead_or_treats_adult() -> void:
	growth.configure(86400.0, 64800.0)
	watch_signals(growth)
	assert_true(growth.apply_juvenile_tonic())
	assert_true(growth.is_adult())
	assert_eq(growth.age_seconds, 64800.0)
	assert_signal_emit_count(growth, "matured", 1)
	assert_false(growth.apply_juvenile_tonic())
	growth.configure(86400.0, 1209600.0)
	assert_false(growth.apply_juvenile_tonic())

func test_adult_bonus_is_exactly_one_roll_for_one_cycle_then_reusable() -> void:
	var rolls: Array[int] = [0]
	production.bonus_roll = func() -> float:
		rolls[0] += 1
		return 0.49
	assert_true(production.apply_tonic())
	assert_false(production.apply_tonic())
	assert_eq(production.advance(9.0), 0)
	assert_true(production.tonic_pending)
	assert_eq(rolls[0], 0)
	assert_eq(production.advance(1001.0), 102, "101 cycles plus exactly one bonus item")
	assert_eq(rolls[0], 1)
	assert_false(production.tonic_pending)
	assert_eq(production.advance(10.0), 1)
	assert_eq(rolls[0], 1)
	assert_true(production.apply_tonic())
	assert_eq(production.advance(10.0), 2)
	assert_eq(rolls[0], 2)

func test_failed_bonus_still_delivers_base_and_clears_before_observers() -> void:
	production.bonus_roll = func() -> float: return 0.5
	production.apply_tonic()
	production.produced.connect(func(amount: int) -> void:
		assert_eq(amount, 1)
		assert_false(production.tonic_pending)
	)
	assert_eq(production.advance(10.0), 1)
	assert_true(production.apply_tonic())
	production.restore_state(5.0, 3, true)
	assert_true(production.tonic_pending)
	assert_eq(production.advance(5.0), 1)
	assert_eq(production.stored_amount, 4)

func test_restored_per_crop_duration_is_the_original_total_not_current_resource_default() -> void:
	crop.restore_progress(crop.definition, 1000.0, 1200.0, 0.0, 1000.0)
	assert_true(crop.apply_fertilizer(1020.0))
	assert_eq(crop.matures_at, 1160.0)
