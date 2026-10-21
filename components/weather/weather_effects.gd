class_name WeatherEffects
extends Node2D
## Bounded camera-relative decoration; only one weather renderer is active.
const RAIN: Texture2D = preload("res://assets/Weather effects/Rain_Drop.png")
const SPLASH: Texture2D = preload("res://assets/Weather effects/Rain_Drop_Impact.png")
const CLOUDS: Texture2D = preload("res://assets/Weather effects/Clouds.png")
var world: FarmWorld
var active_weather: int = WeatherManager.Weather.SUNNY
var strength: float = 0.0
var wind_audio: AudioStreamPlayer
var _tween: Tween
var _phase: float = 0.0
var _area: Vector2 = Vector2(640, 360)
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
	_rain = _atlas(RAIN, Rect2(0, 0, 9, 8))
	for index: int in range(5):
		_splashes.append(_atlas(SPLASH, Rect2(index * 16, 0, 16, 16)))
	for point: Vector2 in [Vector2(0, 0), Vector2(64, 0), Vector2(0, 64), Vector2(64, 64)]:
		_clouds.append(_atlas(CLOUDS, Rect2(point, Vector2(64, 64))))
	wind_audio = AudioStreamPlayer.new()
	wind_audio.stream = preload("res://assets/audio/farm_wind.wav")
	wind_audio.volume_db = -80.0
	add_child(wind_audio)

func transition_to(next: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Fade out, then switch, then fade in: never overlap weather types.
	_tween.tween_property(self, "strength", 0.0, 1.0)
	_tween.tween_callback(_activate.bind(next))
	_tween.tween_property(self, "strength", 1.0, 1.0)

func _activate(next: int) -> void:
	active_weather = next
	z_index = 1 if next == WeatherManager.Weather.CLOUDY else 100
	if next == WeatherManager.Weather.WINDY:
		wind_audio.play()
	else:
		wind_audio.stop()

func weather_tint() -> Color:
	var target: Color = Color(0.7, 0.75, 0.82) if active_weather == WeatherManager.Weather.RAIN else Color(0.93, 0.95, 0.98) if active_weather == WeatherManager.Weather.CLOUDY else Color.WHITE
	return Color.WHITE.lerp(target, strength)

func _process(delta: float) -> void:
	_phase += delta
	var camera: Camera2D = world.player.camera
	_area = get_viewport_rect().size / camera.zoom
	global_position = camera.get_screen_center_position()
	wind_audio.volume_db = linear_to_db(maxf(0.0001, strength * 0.17))
	queue_redraw()

func _draw() -> void:
	if strength <= 0.001:
		return
	var extent: Vector2 = _area + Vector2(80, 80)
	if active_weather == WeatherManager.Weather.RAIN:
		for index: int in range(100):
			var point: Vector2 = Vector2(fposmod(index * 83.31 - _phase * 90.0, extent.x), fposmod(index * 61.73 + _phase * 260.0, extent.y)) - extent * 0.5
			draw_line(point, point + Vector2(-3, 10), Color(0.65, 0.82, 1.0, strength * 0.45), 1.0)
			draw_texture(_rain, point + Vector2(-3, 10), Color(0.65, 0.82, 1.0, strength * 0.75))
		for index: int in range(24):
			var frame: int = int(fposmod(_phase * 10.0 + index * 1.71, 9.0))
			if frame < _splashes.size():
				var point: Vector2 = Vector2(fposmod(index * 137.3, extent.x), fposmod(index * 47.7, extent.y)) - extent * 0.5
				draw_texture(_splashes[frame], point, Color(0.65, 0.82, 1.0, strength * 0.6))
	elif active_weather == WeatherManager.Weather.CLOUDY:
		for index: int in range(9):
			var point: Vector2 = Vector2(fposmod(index * 173.7 + _phase * 5.0, extent.x + 220), fposmod(index * 97.3 + _phase, extent.y + 180)) - extent * 0.5 - Vector2(110, 90)
			draw_texture_rect(_clouds[index % _clouds.size()], Rect2(point, Vector2(192, 144)), false, Color(0, 0, 0, 0.15 * strength))

	elif active_weather == WeatherManager.Weather.WINDY:
		for index: int in range(12):
			var point: Vector2 = Vector2(fposmod(index * 107.31 + _phase * 100.0, extent.x), fposmod(index * 51.73 + _phase * 18.0 + sin(_phase * 3 + index) * 4, extent.y)) - extent * 0.5
			draw_set_transform(point, sin(_phase * 4 + index))
			draw_rect(Rect2(-1, -0.5, 2, 1), Color(1.0, 0.67, 0.73, strength * 0.8))
		draw_set_transform(Vector2.ZERO)
