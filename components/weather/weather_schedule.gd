class_name WeatherSchedule
extends RefCounted
## Deterministic daily weather plus timestamped manual overrides, shared by catch-up.
enum Weather { SUNNY, RAIN, CLOUDY, WINDY }
const DAY: float = 86400.0
const UTC_OFFSET: float = 25200.0
const DAWN: float = 21600.0
var seed: int = 0
var changes: Array[Dictionary] = []

func day_at(timestamp: float) -> int:
	return floori((timestamp + UTC_OFFSET - DAWN) / DAY)

func dawn_at(day: int) -> float:
	return day * DAY - UTC_OFFSET + DAWN

func weather_at(timestamp: float) -> Weather:
	var day: int = day_at(timestamp)
	for index: int in range(changes.size() - 1, -1, -1):
		var entry: Dictionary = changes[index]
		if float(entry.at) <= timestamp and day_at(float(entry.at)) == day:
			return int(entry.weather) as Weather
	# Integer mixing makes reloads and offline queries independent of global RNG.
	var roll: int = posmod((day + seed) * 1103515245 + 12345, 2147483647) % 100
	return Weather.SUNNY if roll < 60 else Weather.RAIN if roll < 80 else Weather.CLOUDY if roll < 90 else Weather.WINDY

func next_boundary(timestamp: float) -> float:
	var result: float = dawn_at(day_at(timestamp) + 1)
	for entry: Dictionary in changes:
		if float(entry.at) > timestamp + 0.000001:
			result = minf(result, float(entry.at))
	return result

func water_rate(timestamp: float) -> float:
	return 0.75 if weather_at(timestamp) == Weather.CLOUDY else 1.0

func evaporation_rate(timestamp: float) -> float:
	var weather: Weather = weather_at(timestamp)
	return 0.0 if weather == Weather.RAIN else 0.75 if weather == Weather.CLOUDY else 1.0

func radius_multiplier(timestamp: float) -> float:
	return 1.5 if weather_at(timestamp) == Weather.WINDY else 1.0

func capture() -> Dictionary:
	return {"seed": seed, "changes": changes.duplicate(true)}

func restore(data: Dictionary) -> void:
	seed = int(data.seed)
	changes.clear()
	for entry: Dictionary in data.changes:
		changes.append(entry.duplicate())
