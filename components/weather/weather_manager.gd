class_name WeatherManager
extends Node
## The farm's single weather authority. Visual fades do not change simulation time.
const Weather = WeatherSchedule.Weather
signal weather_changed(weather: int)
var world: FarmWorld
var schedule: WeatherSchedule = WeatherSchedule.new()
var current_weather: WeatherSchedule.Weather = Weather.SUNNY
var day_night: DayNightComponent
var effects: WeatherEffects
var hud: WeatherHUD
var last_at: float = 0.0
## Debug lighting preview only; never change the simulation clock or save timestamps.
var debug_hour: int = -1
var _rain_day: int = -9223372036854775807
var _rain_columns: int = -1
var _advancing: bool = false

func _ready() -> void:
	last_at = world.farming.time_manager.now()
	day_night = DayNightComponent.new()
	day_night.world = world
	add_child(day_night)
	effects = WeatherEffects.new()
	effects.world = world
	add_child(effects)
	hud = WeatherHUD.new()
	hud.manager = self
	add_child(hud)
	world.farming.time_manager.tick.connect(advance)
	advance(last_at)

func advance(timestamp: float, refresh_visuals: bool = true) -> void:
	if _advancing:
		return
	_advancing = true
	timestamp = maxf(last_at, timestamp)
	var cursor: float = last_at
	_apply_rain(cursor)
	while cursor < timestamp - 0.000001:
		var boundary: float = minf(timestamp, schedule.next_boundary(cursor))
		world.farming.evaporate_soil((boundary - cursor) * schedule.evaporation_rate(cursor))
		cursor = boundary
		_apply_rain(cursor)
	last_at = timestamp
	var next: WeatherSchedule.Weather = schedule.weather_at(timestamp)
	if next != current_weather:
		current_weather = next
		effects.transition_to(next)
		weather_changed.emit(next)
	if refresh_visuals:
		day_night.refresh(display_timestamp(timestamp), effects.weather_tint())
		hud.refresh(display_timestamp(timestamp))
	_advancing = false

func _apply_rain(timestamp: float) -> void:
	var columns: int = world.farming.land.unlocked_columns
	var day: int = schedule.day_at(timestamp)
	if schedule.weather_at(timestamp) == Weather.RAIN and (day != _rain_day or columns != _rain_columns):
		_rain_day = day
		_rain_columns = columns
		world.farming.rain_water()

func set_weather(next_weather: WeatherSchedule.Weather) -> void:
	if _advancing or next_weather < Weather.SUNNY or next_weather > Weather.WINDY:
		return
	var timestamp: float = world.farming.time_manager.now()
	if next_weather == schedule.weather_at(timestamp):
		return
	# Commit the old interval before replacing its weather. Overrides affect only
	# the rest of this day; reloading never applies today's weather to yesterday.
	advance(timestamp)
	world.apiary.advance(timestamp)
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		var animal: AnimalActor = node as AnimalActor
		if world.is_ancestor_of(animal):
			animal.needs.update_at(timestamp)
	schedule.changes.append({"at": timestamp, "weather": int(next_weather)})
	_rain_day = -9223372036854775807
	advance(timestamp)
	world.apiary.advance(timestamp)

func restore(data: Dictionary, timestamp: float) -> void:
	schedule.restore(data)
	last_at = timestamp
	_rain_day = -9223372036854775807
	_rain_columns = -1

func display_timestamp(timestamp: float) -> float:
	if debug_hour < 0:
		return timestamp
	return timestamp - fposmod(timestamp + WeatherSchedule.UTC_OFFSET, 86400.0) + debug_hour * 3600.0

func set_debug_hour(hour: int) -> void:
	if not OS.is_debug_build() or hour < -1 or hour > 23:
		return
	debug_hour = hour
	day_night.refresh(display_timestamp(last_at), effects.weather_tint())
	hud.refresh(display_timestamp(last_at))

func _process(_delta: float) -> void:
	if day_night != null:
		day_night.refresh(display_timestamp(last_at), effects.weather_tint())
