class_name WeatherEffects
extends Node2D
## Cloud/wind paths stay in world space; only visible grid cells are drawn.
const RAIN: Texture2D = preload("res://assets/Weather effects/Rain_Drop.png")
const SPLASH: Texture2D = preload("res://assets/Weather effects/Rain_Drop_Impact.png")
const CLOUDS: Texture2D = preload("res://assets/Weather effects/Clouds.png")
# Roughly twice as many cloud shadows per world area during cloudy weather.
const CLOUD_SPACING: Vector2 = Vector2(176, 132)
const WIND_SPACING: Vector2 = Vector2(128, 112)
const RAIN_SPACING: Vector2 = Vector2(48, 48)
const SPLASH_SPACING: Vector2 = Vector2(96, 96)
var world: FarmWorld
var active_weather: int = WeatherManager.Weather.SUNNY
var strength: float = 0.0
var wind_audio: AudioStreamPlayer
var _tween: Tween
var _phase: float = 0.0
var _rain: AtlasTexture
var _splashes: Array[AtlasTexture] = []
var _clouds: Array[AtlasTexture] = []

func _atlas(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = texture
	result.region = rect
	return result

func _ready() -> void:
	z_index = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	_rain = _atlas(RAIN, Rect2(0, 0, 16, 16))
	for index: int in range(5):
		_splashes.append(_atlas(SPLASH, Rect2(index * 16, 0, 16, 16)))
	for point: Vector2 in [Vector2(0, 0), Vector2(64, 0), Vector2(0, 64), Vector2(64, 64)]:
		_clouds.append(_atlas(CLOUDS, Rect2(point, Vector2(64, 64))))
	wind_audio = AudioStreamPlayer.new()
	wind_audio.stream = preload("res://assets/audio/farm_wind.wav")
	wind_audio.volume_db = -80.0
	add_child(wind_audio)
	set_process(false)

func transition_to(next: int) -> void:
	set_process(true)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Fade out, then switch, then fade in: never overlap weather types.
	_tween.tween_property(self, "strength", 0.0, 1.0)
	_tween.tween_callback(_activate.bind(next))
	_tween.tween_property(self, "strength", 1.0, 1.0)
	_tween.finished.connect(_finish_transition)

func _finish_transition() -> void:
	_tween = null
	if active_weather == WeatherManager.Weather.SUNNY:
		set_process(false)
		queue_redraw()

func _activate(next: int) -> void:
	active_weather = next
	z_index = 1 if next == WeatherManager.Weather.CLOUDY else 100
	position = Vector2.ZERO
	if next == WeatherManager.Weather.WINDY:
		wind_audio.play()
	else:
		wind_audio.stop()

func weather_tint() -> Color:
	var target: Color = Color(0.7, 0.75, 0.82) if active_weather == WeatherManager.Weather.RAIN else Color(0.93, 0.95, 0.98) if active_weather == WeatherManager.Weather.CLOUDY else Color.WHITE
	return Color.WHITE.lerp(target, strength)

func _process(delta: float) -> void:
	_phase += delta
	wind_audio.volume_db = linear_to_db(maxf(0.0001, strength * 0.17))
	queue_redraw()

func _visible_cells(spacing: Vector2, drift: Vector2, padding: float) -> Rect2i:
	# Camera changes only select cells; they never change a cell's path or phase.
	var view: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	view = view.grow(padding)
	var start: Vector2i = Vector2i(((view.position - drift) / spacing).floor())
	var end: Vector2i = Vector2i(((view.end - drift) / spacing).ceil()) + Vector2i.ONE
	return Rect2i(start, end - start)

func _cloud_point(cell: Vector2i) -> Vector2:
	var seed: float = float(cell.x * 73 + cell.y * 137)
	var jitter: Vector2 = Vector2(sin(seed) * 52.0, cos(seed * 1.7) * 38.0)
	return Vector2(cell) * CLOUD_SPACING + Vector2(5, 1) * _phase + jitter

func _wind_point(cell: Vector2i) -> Vector2:
	var seed: float = float(cell.x * 107 + cell.y * 53)
	var jitter: Vector2 = Vector2(sin(seed) * 32.0, cos(seed * 1.3) * 28.0)
	return Vector2(cell) * WIND_SPACING + Vector2(100, 18) * _phase + jitter + Vector2(0, sin(_phase * 3 + seed) * 4)

func _rain_point(cell: Vector2i) -> Vector2:
	var seed: float = float(cell.x * 73 + cell.y * 137)
	var jitter: Vector2 = Vector2(sin(seed), cos(seed * 1.7)) * 18.0
	return Vector2(cell) * RAIN_SPACING + Vector2(-90, 260) * _phase + jitter

func _splash_point(cell: Vector2i) -> Vector2:
	var seed: float = float(cell.x * 107 + cell.y * 53)
	return Vector2(cell) * SPLASH_SPACING + Vector2(sin(seed), cos(seed * 1.7)) * 32.0

func _draw() -> void:
	if strength <= 0.001:
		return
	if active_weather == WeatherManager.Weather.RAIN:
		var drops: Rect2i = _visible_cells(RAIN_SPACING, Vector2(-90, 260) * _phase, 40.0)
		for y: int in range(drops.position.y, drops.end.y):
			for x: int in range(drops.position.x, drops.end.x):
				draw_texture(_rain, _rain_point(Vector2i(x, y)), Color(0.65, 0.82, 1.0, strength * 0.75))
		var splashes: Rect2i = _visible_cells(SPLASH_SPACING, Vector2.ZERO, 48.0)
		for y: int in range(splashes.position.y, splashes.end.y):
			for x: int in range(splashes.position.x, splashes.end.x):
				var frame: int = int(fposmod(_phase * 10.0 + float(x * 73 + y * 137) * 1.71, 9.0))
				if frame < _splashes.size():
					draw_texture(_splashes[frame], _splash_point(Vector2i(x, y)), Color(0.65, 0.82, 1.0, strength * 0.6))
	elif active_weather == WeatherManager.Weather.CLOUDY:
		var cells: Rect2i = _visible_cells(CLOUD_SPACING, Vector2(5, 1) * _phase, 160.0)
		for y: int in range(cells.position.y, cells.end.y):
			for x: int in range(cells.position.x, cells.end.x):
				var cell: Vector2i = Vector2i(x, y)
				var point: Vector2 = _cloud_point(cell) - Vector2(96, 72)
				var index: int = posmod(x * 3 + y, _clouds.size())
				draw_texture_rect(_clouds[index], Rect2(point, Vector2(192, 144)), false, Color(0, 0, 0, 0.15 * strength))

	elif active_weather == WeatherManager.Weather.WINDY:
		var cells: Rect2i = _visible_cells(WIND_SPACING, Vector2(100, 18) * _phase, 40.0)
		for y: int in range(cells.position.y, cells.end.y):
			for x: int in range(cells.position.x, cells.end.x):
				var cell: Vector2i = Vector2i(x, y)
				draw_set_transform(_wind_point(cell), sin(_phase * 4 + float(x * 107 + y * 53)))
				draw_rect(Rect2(-1, -0.5, 2, 1), Color(1.0, 0.67, 0.73, strength * 0.8))
		draw_set_transform(Vector2.ZERO)
