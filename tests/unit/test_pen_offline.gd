extends GutTest

func animal(id: String, food: float = 100.0, water: float = 100.0) -> Dictionary:
	return {"id": id, "species": 0, "satiety": food, "hydration": water, "food_seconds": 3600.0, "water_seconds": 3600.0, "age": 0.0, "lifespan": 1209600.0, "starts_at": 0.0}

func trough(id: String, kind: int, stock: float) -> Dictionary:
	return {"id": id, "kind": kind, "stock": stock, "restoration": 40.0, "species": []}

func supplied(result: Dictionary, id: String) -> float:
	var total: float = 0.0
	for step: Dictionary in result.steps:
		if step.id == id:
			total += float(step.supplied)
	return total

func test_full_barn_uses_2160_units_per_kind_in_24_hours() -> void:
	var herd: Array[Dictionary] = []
	for index: int in range(36):
		herd.append(animal("cow_%02d" % index))
	var stocks: Array[Dictionary] = [trough("f1", 0, 1200), trough("f2", 0, 1200), trough("w1", 1, 1200), trough("w2", 1, 1200)]
	var result: Dictionary = PenOfflineModel.advance(herd, stocks, 0, 86400)
	assert_almost_eq(float(result.troughs[0].stock) + float(result.troughs[1].stock), 240.0, 0.00001)
	assert_almost_eq(float(result.troughs[2].stock) + float(result.troughs[3].stock), 240.0, 0.00001)
	for row: Dictionary in result.animals:
		assert_almost_eq(supplied(result, row.id), 86400.0, 0.00001)
		assert_almost_eq(float(row.satiety), 100.0, 0.00001)
	assert_eq(stocks[0].stock, 1200.0, "The model does not mutate caller state")

func test_empty_troughs_use_body_reserves_and_preserve_half_hour_of_water() -> void:
	var result: Dictionary = PenOfflineModel.advance([animal("a", 100, 50)], [], 0, 7200)
	assert_almost_eq(supplied(result, "a"), 1800.0, 0.00001)
	assert_eq(result.animals[0].satiety, 0.0)
	assert_eq(result.animals[0].hydration, 0.0)

func test_stock_exhaustion_is_fair_and_independent_of_actor_order() -> void:
	var herd: Array[Dictionary] = [animal("a"), animal("b")]
	var stocks: Array[Dictionary] = [trough("f", 0, 5), trough("w", 1, 100)]
	var result: Dictionary = PenOfflineModel.advance(herd, stocks, 0, 10800)
	herd.reverse()
	var reverse_result: Dictionary = PenOfflineModel.advance(herd, stocks, 0, 10800)
	assert_eq(result, reverse_result)
	assert_almost_eq(supplied(result, "a"), 7200.0, 0.00001)
	assert_almost_eq(supplied(result, "b"), 7200.0, 0.00001)

func test_short_and_long_catchup_match_including_fractional_units() -> void:
	var herd: Array[Dictionary] = [animal("a", 25, 60), animal("b", 75, 40)]
	var stocks: Array[Dictionary] = [trough("f", 0, 4.375), trough("w", 1, 9.125)]
	var whole: Dictionary = PenOfflineModel.advance(herd, stocks, 0, 12000)
	var first: Dictionary = PenOfflineModel.advance(herd, stocks, 0, 1234)
	var split: Dictionary = PenOfflineModel.advance(first.animals, first.troughs, 1234, 12000)
	for index: int in range(herd.size()):
		assert_almost_eq(float(whole.animals[index].satiety), float(split.animals[index].satiety), 0.00001)
		assert_almost_eq(float(whole.animals[index].hydration), float(split.animals[index].hydration), 0.00001)
		assert_almost_eq(supplied(whole, herd[index].id), supplied(first, herd[index].id) + supplied(split, herd[index].id), 0.00001)
	for index: int in range(stocks.size()):
		assert_almost_eq(float(whole.troughs[index].stock), float(split.troughs[index].stock), 0.00001)

func test_death_stops_consumption_and_late_arrivals_do_not_eat_in_the_past() -> void:
	var young: Dictionary = animal("young")
	young.starts_at = 3600.0
	var old: Dictionary = animal("old")
	old.lifespan = 1800.0
	var result: Dictionary = PenOfflineModel.advance([old, young], [trough("f", 0, 100), trough("w", 1, 100)], 0, 7200)
	assert_almost_eq(supplied(result, "old"), 1800.0, 0.00001)
	assert_almost_eq(supplied(result, "young"), 3600.0, 0.00001)
	assert_almost_eq(float(result.troughs[0].stock), 96.25, 0.00001)

func test_cloudy_weather_reduces_water_and_restricted_troughs_cannot_feed_other_species() -> void:
	var weather: WeatherSchedule = WeatherSchedule.new()
	weather.changes = [{"at": 0.0, "weather": WeatherSchedule.Weather.CLOUDY}]
	var food: Dictionary = trough("f", 0, 100)
	food.species = [1]
	var result: Dictionary = PenOfflineModel.advance([animal("a")], [food, trough("w", 1, 100)], 0, 7200, weather)
	assert_almost_eq(float(result.troughs[0].stock), 100.0, 0.00001)
	assert_almost_eq(float(result.troughs[1].stock), 96.25, 0.00001)
	assert_almost_eq(supplied(result, "a"), 3600.0, 0.00001)

func test_repeating_timestamp_or_backwards_clock_does_not_consume_anything() -> void:
	var result: Dictionary = PenOfflineModel.advance([animal("a")], [trough("f", 0, 100)], 0, 10)
	var repeat: Dictionary = PenOfflineModel.advance(result.animals, result.troughs, 10, 10)
	assert_eq(repeat.steps.size(), 0)
	assert_eq(repeat.troughs, result.troughs)
	assert_eq(repeat.animals, result.animals)
	var backwards: Dictionary = PenOfflineModel.advance(result.animals, result.troughs, 10, 5)
	assert_eq(backwards.animals, result.animals)
	assert_eq(backwards.troughs, result.troughs)

func test_empty_pen_and_long_gap_after_death_do_not_consume_stock() -> void:
	var empty: Dictionary = PenOfflineModel.advance([], [trough("f", 0, 100)], 0, 31536000)
	assert_eq(empty.steps.size(), 0)
	assert_eq(empty.troughs[0].stock, 100.0)
	var old: Dictionary = animal("old")
	old.lifespan = 3600.0
	var result: Dictionary = PenOfflineModel.advance([old], [trough("f", 0, 100), trough("w", 1, 100)], 0, 31536000)
	assert_eq(result.steps.size(), 1, "A year gap does not replay every second/day after death")
	assert_almost_eq(float(result.troughs[0].stock), 97.5, 0.00001)
	assert_almost_eq(supplied(result, "old"), 3600.0, 0.00001)

func test_irregular_partitions_preserve_weather_death_arrival_and_fractional_stock() -> void:
	var weather: WeatherSchedule = WeatherSchedule.new()
	weather.seed = 12345
	weather.changes = [
		{"at": 0.0, "weather": WeatherSchedule.Weather.CLOUDY},
		{"at": 4000.0, "weather": WeatherSchedule.Weather.RAIN},
		{"at": 9000.0, "weather": WeatherSchedule.Weather.SUNNY}]
	var late: Dictionary = animal("late", 65.0, 30.0)
	late.starts_at = 3500.0
	var old: Dictionary = animal("old", 80.0, 60.0)
	old.lifespan = 7500.0
	var herd: Array[Dictionary] = [late, old, animal("resident", 35.0, 90.0)]
	var stocks: Array[Dictionary] = [trough("f", 0, 8.125), trough("w", 1, 13.375)]
	var input_herd: Array[Dictionary] = herd.duplicate(true)
	var input_stocks: Array[Dictionary] = stocks.duplicate(true)
	var whole: Dictionary = PenOfflineModel.advance(herd, stocks, 0.0, 100000.0, weather)
	var totals: Dictionary = {"late": 0.0, "old": 0.0, "resident": 0.0}
	var cursor: float = 0.0
	for boundary: float in [1.0, 3499.5, 3500.0, 4000.0, 7499.75, 7500.0, 9000.0, 86400.0, 100000.0]:
		var part: Dictionary = PenOfflineModel.advance(herd, stocks, cursor, boundary, weather)
		for id: String in totals:
			totals[id] += supplied(part, id)
		herd.assign(part.animals)
		stocks.assign(part.troughs)
		cursor = boundary
	for index: int in range(herd.size()):
		assert_eq(herd[index].id, whole.animals[index].id)
		for field: String in ["satiety", "hydration", "age"]:
			assert_almost_eq(float(herd[index][field]), float(whole.animals[index][field]), 0.00001)
		assert_almost_eq(float(totals[herd[index].id]), supplied(whole, herd[index].id), 0.00001)
	for index: int in range(stocks.size()):
		assert_almost_eq(float(stocks[index].stock), float(whole.troughs[index].stock), 0.00001)
	var repeated: Dictionary = PenOfflineModel.advance(input_herd, input_stocks, 0.0, 100000.0, weather)
	assert_eq(repeated, whole, "The reference calculation must be deterministic")
