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
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
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
	pot.restore_state({"planted_at": 800.0, "growth_started_at": 800.0, "matures_at": 900.0, "progress": 1.0}, load("res://flowers/definitions/flower_06.tres"), now)
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
	hive.production.contributions = {"flower_06": 30.0}
	hive.bees._visibility(true)
	assert_true(hive.bees._bees[0].visible)
	world.weather.set_weather(WeatherManager.Weather.RAIN)
	assert_false(hive.bees.is_processing())
	assert_false(hive.bees._bees[0].visible)
	assert_true(hive.bees.visible)
	now += 10
	world.apiary.advance(now)
	assert_eq(hive.production.work, 60.0)
	assert_eq(hive.production.contributions.flower_06, 30.0)
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	assert_true(hive.bees._bees[0].visible)

func test_rain_waterfowl_produce_ten_percent_faster_only_while_supplied_and_adult() -> void:
	var pen: PondPen = world.get_node("PondPen") as PondPen
	var duck: AnimalActor = preload("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
	duck.definition = preload("res://animals/definitions/duck.tres")
	duck.pen = pen
	duck.needs.time_manager = clock
	pen.add_child(duck)
	for child: Node in pen.get_children():
		if child is AnimalTrough:
			(child as AnimalTrough).stock = 0
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
	assert_eq(check.snapshot.version, SaveSchema.VERSION)
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

func test_lamps_never_darken_daylight_while_fading_at_dawn_and_dusk() -> void:
	var lighting: DayNightComponent = world.weather.day_night
	assert_eq(lighting.lights.size(), world.night_light_positions.size() + 1, "Include the moving land sign lamp")
	for light: PointLight2D in lighting.lights:
		assert_eq(light.blend_mode, Light2D.BLEND_MODE_ADD, "A fading lamp must add light, never mix a darker color over the world")
	for hour: float in [6.0, 17.5, 23.0]:
		lighting.refresh(hour * 3600.0 - WeatherSchedule.UTC_OFFSET, Color.WHITE)
		for light: PointLight2D in lighting.lights:
			assert_true(light.enabled, "Visible lamps stay lit through dawn, dusk and night")
			assert_gt(light.energy, 0.0)
	for tint: Color in [Color.WHITE, Color(0.8, 0.85, 0.9)]:
		lighting.refresh(12 * 3600 - WeatherSchedule.UTC_OFFSET, tint)
		assert_eq(lighting.ambient.color, tint)
		for light: PointLight2D in lighting.lights:
			assert_false(light.enabled, "No lamps at noon, including overcast weather")
			assert_eq(light.energy, 0.0)

func test_effects_sleep_after_sunny_fade_and_wake_without_skipping_transitions() -> void:
	var effects: WeatherEffects = world.weather.effects
	assert_false(effects.is_processing())
	for next: int in [WeatherManager.Weather.RAIN, WeatherManager.Weather.CLOUDY, WeatherManager.Weather.WINDY, WeatherManager.Weather.SUNNY]:
		var previous: int = effects.active_weather
		effects.transition_to(next)
		assert_true(effects.is_processing())
		var fade: Tween = effects._tween
		fade.custom_step(0.5)
		assert_eq(effects.active_weather, previous, "Fade out the old weather before switching")
		fade.custom_step(0.6)
		assert_eq(effects.active_weather, next)
		assert_true(effects.is_processing(), "Keep the entire fade in")
		fade.custom_step(1.0)
		assert_almost_eq(effects.strength, 1.0, 0.00001)
		assert_eq(effects.is_processing(), next != WeatherManager.Weather.SUNNY)
		assert_eq(effects.wind_audio.playing, next == WeatherManager.Weather.WINDY)
	effects.transition_to(WeatherManager.Weather.RAIN)
	effects._tween.custom_step(1.2)
	effects.transition_to(WeatherManager.Weather.CLOUDY)
	effects._tween.custom_step(2.1)
	assert_eq(effects.active_weather, WeatherManager.Weather.CLOUDY)
	assert_true(effects.is_processing())

func test_debug_panel_lists_groups_and_can_be_opened_and_closed() -> void:
	Language.set_language("en")
	var hud: WeatherHUD = world.weather.hud
	assert_not_null(hud.debug_toggle)
	assert_false(hud.debug_bar.visible)
	hud.debug_toggle.button_pressed = true
	assert_true(hud.debug_bar.visible)
	assert_eq(hud._time_title.text, "Day and night")
	assert_eq(hud._weather_title.text, "Weather")
	Language.set_language("vi")
	assert_eq(hud._time_title.text, "Ngày và đêm")
	assert_eq(hud._weather_title.text, "Thời tiết")
	assert_true(hud.debug_bar.visible)
	Language.set_language("en")
	hud.debug_toggle.button_pressed = false
	assert_false(hud.debug_bar.visible)

func test_debug_time_buttons_preview_day_night_without_advancing_the_farm_clock() -> void:
	var manager: WeatherManager = world.weather
	var hud: WeatherHUD = manager.hud
	assert_not_null(hud.debug_bar)
	assert_eq(hud.time_buttons.size(), 3)
	var original_time: float = manager.last_at
	var original_apiary_time: float = world.apiary.last_at
	var original_history_size: int = manager.schedule.changes.size()
	var original_text: String = hud.label.text
	hud.time_buttons[1].pressed.emit()
	assert_eq(manager.debug_hour, 23)
	assert_string_contains(hud.label.text, "23:00")
	assert_eq(manager.day_night.ambient.color, Color(0.22, 0.25, 0.45))
	manager._process(0.1)
	assert_eq(manager.day_night.ambient.color, Color(0.22, 0.25, 0.45), "Weather fade updates must retain the preview")
	hud.time_buttons[0].pressed.emit()
	assert_string_contains(hud.label.text, "12:00")
	assert_eq(manager.day_night.ambient.color, Color.WHITE)
	assert_true(hud.time_buttons[0].button_pressed)
	assert_false(hud.time_buttons[1].button_pressed)
	assert_eq(clock.now(), now)
	assert_eq(manager.last_at, original_time)
	assert_eq(world.apiary.last_at, original_apiary_time)
	assert_eq(manager.schedule.changes.size(), original_history_size)
	hud.time_buttons[2].pressed.emit()
	assert_eq(manager.debug_hour, -1)
	assert_eq(hud.label.text, original_text)
	assert_true(hud.time_buttons[2].button_pressed)

func test_rain_paths_do_not_follow_camera_pan_or_zoom() -> void:
	var effects: WeatherEffects = world.weather.effects
	var camera: Camera2D = world.player.camera
	world.position = Vector2(96, 48)
	world.scale = Vector2(1.5, 1.25)
	effects._activate(WeatherManager.Weather.RAIN)
	effects._phase = 7.5
	effects._process(0.0)
	var cell: Vector2i = Vector2i(2, -1)
	var drop: Vector2 = effects.to_global(effects._rain_point(cell))
	var splash: Vector2 = effects.to_global(effects._splash_point(cell))
	camera.global_position += Vector2(240, 128)
	camera.zoom = Vector2(5, 5)
	camera.force_update_scroll()
	effects._process(0.0)
	assert_eq(effects.to_global(effects._rain_point(cell)), drop)
	assert_eq(effects.to_global(effects._splash_point(cell)), splash)
	effects._process(1.0)
	assert_true((effects._rain_point(cell) - effects.to_local(drop)).is_equal_approx(Vector2(-90, 260)))
	assert_eq(effects.to_global(effects._splash_point(cell)), splash)

func test_cloud_and_wind_paths_do_not_follow_camera_pan_zoom_or_world_transform() -> void:
	var effects: WeatherEffects = world.weather.effects
	var camera: Camera2D = world.player.camera
	world.position = Vector2(96, 48)
	world.scale = Vector2(1.5, 1.25)
	for kind: int in [WeatherManager.Weather.CLOUDY, WeatherManager.Weather.WINDY]:
		# Start after rain to catch a stale camera-following origin on transitions.
		effects._activate(WeatherManager.Weather.RAIN)
		effects._process(0.0)
		effects._activate(kind)
		effects._phase = 7.5
		effects._process(0.0)
		var cell: Vector2i = Vector2i(2, -1)
		var local_point: Vector2 = effects._cloud_point(cell) if kind == WeatherManager.Weather.CLOUDY else effects._wind_point(cell)
		var world_point: Vector2 = effects.to_global(local_point)
		var origin: Vector2 = effects.global_position
		camera.global_position += Vector2(240, 128)
		camera.zoom = Vector2(5, 5)
		camera.force_update_scroll()
		effects._process(0.0)
		var moved_point: Vector2 = effects._cloud_point(cell) if kind == WeatherManager.Weather.CLOUDY else effects._wind_point(cell)
		assert_eq(effects.position, Vector2.ZERO)
		assert_eq(effects.global_position, origin)
		assert_eq(effects.to_global(moved_point), world_point, "A stationary weather feature stays over the same world location")
		effects._process(1.0)
		var drifted: Vector2 = effects._cloud_point(cell) if kind == WeatherManager.Weather.CLOUDY else effects._wind_point(cell)
		if kind == WeatherManager.Weather.CLOUDY:
			assert_true((drifted - local_point).is_equal_approx(Vector2(5, 1)))
		else:
			assert_almost_eq(drifted.x - local_point.x, 100.0, 0.001)
			assert_ne(drifted, local_point, "Wind still moves independently with time")

func test_weather_grid_covers_resized_views_without_changing_existing_feature_positions() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(640, 360)
	add_child_autofree(view)
	var effects: WeatherEffects = WeatherEffects.new()
	view.add_child(effects)
	effects._phase = 10000.0
	for kind: int in [WeatherManager.Weather.CLOUDY, WeatherManager.Weather.WINDY]:
		var spacing: Vector2 = WeatherEffects.CLOUD_SPACING if kind == WeatherManager.Weather.CLOUDY else WeatherEffects.WIND_SPACING
		var drift: Vector2 = Vector2(5, 1) * effects._phase if kind == WeatherManager.Weather.CLOUDY else Vector2(100, 18) * effects._phase
		var padding: float = 160.0 if kind == WeatherManager.Weather.CLOUDY else 40.0
		view.canvas_transform = Transform2D(0.0, Vector2(320, 180))
		var small: Rect2i = effects._visible_cells(spacing, drift, padding)
		var cell: Vector2i = small.position + small.size / 2
		var point: Vector2 = effects._cloud_point(cell) if kind == WeatherManager.Weather.CLOUDY else effects._wind_point(cell)
		for size: Vector2i in [Vector2i(500, 281), Vector2i(1920, 1080)]:
			view.size = size
			var cells: Rect2i = effects._visible_cells(spacing, drift, padding)
			var local_view: Rect2 = effects.get_global_transform_with_canvas().affine_inverse() * effects.get_viewport_rect()
			var covered: Rect2 = Rect2(Vector2(cells.position) * spacing + drift, Vector2(cells.size) * spacing)
			assert_true(covered.encloses(local_view.grow(padding)), "Drawing cells cover the viewport, including the entry margin")
			assert_lt(cells.get_area(), 400, "Work stays bounded by visible area after a long session")
			var same_point: Vector2 = effects._cloud_point(cell) if kind == WeatherManager.Weather.CLOUDY else effects._wind_point(cell)
			assert_eq(same_point, point)
	view.canvas_transform = Transform2D.IDENTITY
	effects._activate(WeatherManager.Weather.SUNNY)

func test_debug_weather_buttons_use_normal_transitions_and_track_the_active_choice() -> void:
	var hud: WeatherHUD = world.weather.hud
	assert_eq(hud.weather_buttons.size(), 4)
	for kind: int in [WeatherManager.Weather.WINDY, WeatherManager.Weather.RAIN, WeatherManager.Weather.CLOUDY, WeatherManager.Weather.SUNNY]:
		hud.weather_buttons[kind].pressed.emit()
		assert_eq(world.weather.current_weather, kind)
		assert_eq(world.weather.schedule.weather_at(now), kind)
		world.weather.effects._tween.custom_step(2.1)
		assert_eq(world.weather.effects.active_weather, kind)
		for index: int in range(4):
			assert_eq(hud.weather_buttons[index].button_pressed, index == kind)
	assert_eq(hud.weather_buttons[0].text, "Sunny")
	Language.set_language("vi")
	assert_eq(hud.weather_buttons[0].text, "Nắng")
	assert_eq(hud.time_buttons[1].text, "Đêm")
	Language.set_language("en")

func test_offline_weather_boundaries_do_not_retroactively_extend_pollen_or_crop_bonus() -> void:
	var cell: Vector2i = Vector2i(56, 22)
	var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))
	var hive: Beehive = world.apiary.create_hive(point - Vector2(112, 0), &"offline_weather")
	var pot: FlowerPot = world.apiary.gardens[0].pots[Vector2i(0, 0)]
	pot.global_position = point
	pot.restore_state({"planted_at": 800.0, "growth_started_at": 800.0, "matures_at": 900.0, "progress": 1.0}, load("res://flowers/definitions/flower_06.tres"), now)
	assert_true(world.farming.till(cell, world.player))
	var crop: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	crop.growth_seconds = 1000
	world.farming.restore_crop(cell, crop, now, now + 1000, 0, now)
	world.weather.schedule.changes = [{"at": 1050.0, "weather": WeatherManager.Weather.WINDY}, {"at": 1075.0, "weather": WeatherManager.Weather.RAIN}]
	now = 1100
	world.apiary.advance(now)
	assert_almost_eq(hive.production.work, 125.0, 0.00001)
	assert_almost_eq(hive.production.contributions.flower_06, 50.0, 0.00001)
	assert_almost_eq(world.farming.get_crop(cell).pollination_reduction, 2.5, 0.00001)
	assert_false(hive.pollination.active())
	world.apiary.advance(now)
	assert_almost_eq(hive.production.work, 125.0, 0.00001)

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
	# Fresh profiles open four columns (53..56); 52 is the first locked column.
	assert_eq(world.farming.land.unlocked_columns, 4)
	assert_ne(world.farming.get_soil_state(Vector2i(52, 22)), FarmingController.Soil.WET)
