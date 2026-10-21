extends GutTest

func test_dawn_is_six_local_and_midnight_does_not_reroll() -> void:
	var schedule: WeatherSchedule = WeatherSchedule.new()
	var dawn: float = schedule.dawn_at(20000)
	assert_eq(fposmod(dawn + WeatherSchedule.UTC_OFFSET, 86400.0), 21600.0)
	assert_eq(schedule.day_at(dawn - 1), 19999)
	assert_eq(schedule.day_at(dawn), 20000)
	assert_eq(schedule.day_at(dawn + 20 * 3600), 20000)
	assert_eq(schedule.next_boundary(dawn + 1), dawn + 86400)

func test_daily_weather_is_stable_weighted_and_does_not_use_global_rng() -> void:
	var schedule: WeatherSchedule = WeatherSchedule.new()
	var counts: Array[int] = [0, 0, 0, 0]
	for day: int in range(10000, 20000):
		var timestamp: float = schedule.dawn_at(day)
		var kind: int = schedule.weather_at(timestamp)
		counts[kind] += 1
		assert_eq(schedule.weather_at(timestamp + 86399), kind)
	for index: int in range(4):
		assert_almost_eq(float(counts[index]) / 10000, [0.6, 0.2, 0.1, 0.1][index], 0.02)
	var other: WeatherSchedule = WeatherSchedule.new()
	assert_eq(other.weather_at(123456789), schedule.weather_at(123456789))

func test_override_starts_at_its_timestamp_and_expires_at_next_dawn() -> void:
	var schedule: WeatherSchedule = WeatherSchedule.new()
	schedule.changes = [{"at": 1000.0, "weather": WeatherSchedule.Weather.RAIN}, {"at": 1100.0, "weather": WeatherSchedule.Weather.WINDY}]
	assert_eq(schedule.weather_at(999), WeatherSchedule.Weather.SUNNY)
	assert_eq(schedule.weather_at(1000), WeatherSchedule.Weather.RAIN)
	assert_eq(schedule.next_boundary(1000), 1100.0)
	assert_eq(schedule.weather_at(1100), WeatherSchedule.Weather.WINDY)
	var next_dawn: float = schedule.dawn_at(1)
	assert_eq(schedule.weather_at(next_dawn), WeatherSchedule.new().weather_at(next_dawn))
	var restored: WeatherSchedule = WeatherSchedule.new()
	restored.restore(schedule.capture())
	assert_eq(restored.weather_at(1050), WeatherSchedule.Weather.RAIN)

func test_palette_matches_art_direction_and_has_no_black_overlay() -> void:
	assert_eq(DayNightComponent.daylight_color(12 * 3600 - WeatherSchedule.UTC_OFFSET), Color.WHITE)
	assert_eq(DayNightComponent.daylight_color(5 * 3600 - WeatherSchedule.UTC_OFFSET), Color(1, 0.85, 0.75))
	assert_eq(DayNightComponent.daylight_color(18.5 * 3600 - WeatherSchedule.UTC_OFFSET), Color(0.95, 0.65, 0.45))
	assert_eq(DayNightComponent.daylight_color(23 * 3600 - WeatherSchedule.UTC_OFFSET), Color(0.22, 0.25, 0.45))
	for hour: float in [4.5, 5.0, 7.0, 16.5, 18.5, 19.0]:
		var timestamp: float = hour * 3600 - WeatherSchedule.UTC_OFFSET
		assert_true(DayNightComponent.daylight_color(timestamp - 0.01).is_equal_approx(DayNightComponent.daylight_color(timestamp + 0.01)))

func test_cloudy_needs_split_at_weather_change_and_never_award_supplied_time_after_thirst() -> void:
	var needs: AnimalNeedsComponent = AnimalNeedsComponent.new()
	autofree(needs)
	needs.configure(10000, 100)
	needs.restore_state(100, 100, 1000)
	needs.weather = WeatherSchedule.new()
	needs.weather.changes = [{"at": 1050.0, "weather": WeatherSchedule.Weather.CLOUDY}]
	var supplied: Array[float] = []
	needs.time_advanced.connect(func(_at: float, _elapsed: float, eligible: float) -> void: supplied.append(eligible))
	needs.update_at(1100)
	assert_almost_eq(needs.hydration, 12.5, 0.00001)
	assert_eq(supplied, [50.0, 50.0])
	needs.update_at(1200)
	assert_almost_eq(supplied[2], 100.0 / 6, 0.00001)
	assert_eq(needs.hydration, 0.0)
	needs.update_at(1100)
	assert_eq(supplied.size(), 3)
