extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var clock: FarmClock
var now: float = 1000.0

func _clocks(node: Node) -> void:
	if node is AnimalNeedsComponent:
		(node as AnimalNeedsComponent).time_manager = clock
	if node is FlowerGarden:
		(node as FlowerGarden).time_manager = clock
	for child: Node in node.get_children():
		_clocks(child)

func before_each() -> void:
	now = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return now
	add_child_autofree(clock)
	clock.set_process(false)
	world = WORLD.instantiate() as FarmWorld
	for node: Node in world.get_children():
		if String(node.name).begins_with("TreeScatter"):
			node.free()
	world.farming.time_manager = clock
	_clocks(world)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for garden: FlowerGarden in world.apiary.gardens:
		for pot: FlowerPot in garden.pots.values():
			pot.clear()

func test_rain_waters_only_open_columns_and_keeps_them_wet_until_rain_ends() -> void:
	world.farming.land.restore_columns(10)
	world.weather.set_weather(WeatherManager.Weather.RAIN)
	assert_eq(world.farming.get_soil_state(Vector2i(56, 22)), FarmingController.Soil.WET)
	assert_eq(world.farming.get_soil_state(Vector2i(47, 22)), FarmingController.Soil.WET)
	assert_ne(world.farming.get_soil_state(Vector2i(46, 22)), FarmingController.Soil.WET)
	now += 20000
	world.weather.advance(now)
	assert_eq(world.farming.get_soil_state(Vector2i(56, 22)), FarmingController.Soil.WET)
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	now += FarmingController.SOIL_MOISTURE_SECONDS
	world.weather.advance(now)
	assert_eq(world.farming.get_soil_state(Vector2i(56, 22)), FarmingController.Soil.DRY)
	assert_ne(world.farming.get_soil_state(Vector2i(46, 22)), FarmingController.Soil.WET)

func test_cloudy_soil_lasts_eight_hours_and_offline_moisture_is_not_reset_on_load() -> void:
	var cell: Vector2i = Vector2i(56, 22)
	assert_true(world.farming.till(cell, world.player))
	assert_true(world.farming.water(cell, world.player))
	world.weather.set_weather(WeatherManager.Weather.CLOUDY)
	now += 6 * 3600
	world.weather.advance(now)
	assert_eq(world.farming.get_soil_state(cell), FarmingController.Soil.WET)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("weather", 1, now)
	now += 2 * 3600
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(world.farming.get_soil_state(cell), FarmingController.Soil.DRY)

func test_wind_extends_actual_assignment_crop_buff_and_preview_without_mutating_resource() -> void:
	var point: Vector2 = Vector2(1608, 408)
	var hive: Beehive = world.apiary.create_hive(point, &"weather_hive")
	var pot: FlowerPot = world.apiary.gardens[0].pots[Vector2i(0, 0)]
	pot.global_position = point + Vector2(112, 0)
	pot.restore_state({"planted_at": 800.0, "growth_started_at": 800.0, "matures_at": 900.0, "progress": 1.0}, load("res://flowers/definitions/flower_01.tres"), now)
	world.apiary.advance(now)
	assert_false(hive.pollination.active())
	world.weather.set_weather(WeatherManager.Weather.WINDY)
	assert_true(hive.pollination.active())
	assert_true(world.apiary.crop_is_pollinated(point + Vector2(110, 0)))
	assert_eq(hive.range_display.radius, 120.0)
	assert_eq(hive.definition.radius, 80.0)
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	assert_false(hive.pollination.active())
	assert_eq(hive.range_display.radius, 80.0)

func test_rain_shelters_bees_and_retains_existing_honey_and_pollen_credit() -> void:
	var hive: Beehive = world.apiary.create_hive(Vector2(1608, 408), &"rain_hive")
	hive.production.work = 50
	hive.production.contributions = {"flower_01": 30.0}
	hive.bees._visibility(true)
	assert_true(hive.bees._bees[0].visible)
	world.weather.set_weather(WeatherManager.Weather.RAIN)
	assert_false(hive.bees.is_processing())
	assert_false(hive.bees._bees[0].visible)
	assert_true(hive.bees.visible)
	now += 10
	world.apiary.advance(now)
	assert_eq(hive.production.work, 60.0)
	assert_eq(hive.production.contributions.flower_01, 30.0)
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	assert_true(hive.bees._bees[0].visible)

func test_rain_waterfowl_produce_ten_percent_faster_only_while_supplied_and_adult() -> void:
	var pen: PondPen = world.get_node("PondPen") as PondPen
	var duck: AnimalActor
	for child: Node in pen.get_children():
		if child is AnimalActor and (child as AnimalActor).definition.animal_id == &"duck":
			duck = child as AnimalActor
			break
	assert_not_null(duck)
	duck.growth.configure(0, 0, 100000)
	duck.needs.configure(10000, 10000)
	duck.needs.restore_state(100, 100, now)
	duck.production.progress_seconds = 0
	world.weather.set_weather(WeatherManager.Weather.RAIN)
	now += 10
	duck.needs.update_at(now)
	assert_almost_eq(duck.production.progress_seconds, 11.0, 0.00001)
	duck.needs.restore_state(0, 0, now)
	now += 10
	duck.needs.update_at(now)
	assert_almost_eq(duck.production.progress_seconds, 11.0, 0.00001)

func test_v9_migration_and_weather_roundtrip_reject_invalid_data_before_mutation() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	world.weather.set_weather(WeatherManager.Weather.CLOUDY)
	var saved: Dictionary = adapter.capture("weather", 1, now)
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 9
	legacy.erase("weather")
	for row: Dictionary in legacy.soil:
		row.erase("moisture")
	var check: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(check.ok)
	assert_eq(check.snapshot.version, 10)
	assert_false(legacy.has("weather"))
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(world.weather.current_weather, WeatherManager.Weather.CLOUDY)
	var broken: Dictionary = saved.duplicate(true)
	broken.weather.changes[0].weather = 5
	broken.coins = 0
	var before: int = world.player.wallet.balance
	assert_false(adapter.restore(broken, now).ok)
	assert_eq(world.player.wallet.balance, before)
	var manager: WeatherManager = world.weather
	world.weather = null
	assert_false(adapter.restore(saved, now).ok, "Old hot-reloaded worlds must request restart before mutation")
	world.weather = manager

func test_sequential_fades_and_ui_stay_separate_from_world_tint() -> void:
	var effects: WeatherEffects = world.weather.effects
	effects._activate(WeatherManager.Weather.WINDY)
	assert_true(effects.wind_audio.playing)
	effects._activate(WeatherManager.Weather.RAIN)
	assert_false(effects.wind_audio.playing)
	world.weather.day_night.refresh(23 * 3600 - WeatherSchedule.UTC_OFFSET, Color.WHITE)
	assert_eq(world.weather.day_night.ambient.color, Color(0.22, 0.25, 0.45))
	assert_gt(world.weather.day_night.lights[0].energy, 0.0)
	assert_eq(world.weather.hud.label.modulate, Color.WHITE)
	world.weather.day_night.refresh(12 * 3600 - WeatherSchedule.UTC_OFFSET, Color.WHITE)
	assert_false(world.weather.day_night.lights[0].enabled)

func test_offline_weather_boundaries_do_not_retroactively_extend_pollen_or_crop_bonus() -> void:
	var cell: Vector2i = Vector2i(56, 22)
	var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))
	var hive: Beehive = world.apiary.create_hive(point - Vector2(112, 0), &"offline_weather")
	var pot: FlowerPot = world.apiary.gardens[0].pots[Vector2i(0, 0)]
	pot.global_position = point
	pot.restore_state({"planted_at": 800.0, "growth_started_at": 800.0, "matures_at": 900.0, "progress": 1.0}, load("res://flowers/definitions/flower_01.tres"), now)
	assert_true(world.farming.till(cell, world.player))
	var crop: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	crop.growth_seconds = 1000
	world.farming.restore_crop(cell, crop, now, now + 1000, 0, now)
	world.weather.schedule.changes = [{"at": 1050.0, "weather": WeatherManager.Weather.WINDY}, {"at": 1075.0, "weather": WeatherManager.Weather.RAIN}]
	now = 1100
	world.apiary.advance(now)
	assert_almost_eq(hive.production.work, 107.5, 0.00001)
	assert_almost_eq(hive.production.contributions.flower_01, 32.5, 0.00001)
	assert_almost_eq(world.farming.get_crop(cell).pollination_reduction, 2.5, 0.00001)
	assert_false(hive.pollination.active())
	world.apiary.advance(now)
	assert_almost_eq(hive.production.work, 107.5, 0.00001)

func test_crossing_rainy_dawn_offline_waters_only_owned_soil() -> void:
	var day: int = 1
	while world.weather.schedule.weather_at(world.weather.schedule.dawn_at(day)) != WeatherManager.Weather.RAIN:
		day += 1
	var dawn: float = world.weather.schedule.dawn_at(day)
	world.weather.restore(WeatherSchedule.new().capture(), dawn - 1)
	now = dawn + 1
	world.weather.advance(now)
	assert_eq(world.weather.current_weather, WeatherManager.Weather.RAIN)
	assert_eq(world.farming.get_soil_state(Vector2i(56, 22)), FarmingController.Soil.WET)
	assert_ne(world.farming.get_soil_state(Vector2i(55, 22)), FarmingController.Soil.WET)
