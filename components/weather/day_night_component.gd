class_name DayNightComponent
extends Node2D
## World-only tint. HUD CanvasLayers keep their original colors.
var world: FarmWorld
var ambient: CanvasModulate
var lights: Array[PointLight2D] = []
var darkness: float = 0.0
var _phase: float = 0.0
var _firefly_material: CanvasItemMaterial

static func daylight_color(timestamp: float) -> Color:
	var hour: float = fposmod(timestamp + WeatherSchedule.UTC_OFFSET, 86400.0) / 3600.0
	var stops: Array[float] = [0.0, 4.5, 5.0, 7.0, 16.5, 18.5, 19.0, 24.0]
	var navy: Color = Color(0.22, 0.25, 0.45)
	var colors: Array[Color] = [navy, navy, Color(1, 0.85, 0.75), Color.WHITE, Color.WHITE, Color(0.95, 0.65, 0.45), navy, navy]
	for index: int in range(stops.size() - 1):
		if hour <= stops[index + 1]:
			var weight: float = smoothstep(stops[index], stops[index + 1], hour)
			return colors[index].lerp(colors[index + 1], weight)
	return navy

func _ready() -> void:
	ambient = CanvasModulate.new()
	add_child(ambient)
	_firefly_material = CanvasItemMaterial.new()
	_firefly_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _firefly_material
	z_index = 30
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var glow: GradientTexture2D = GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 1.0)
	# MIX darkens daylight when the lamp fades below the ambient brightness.
	for anchor: Vector2 in world.night_light_positions:
		var light: PointLight2D = PointLight2D.new()
		light.position = anchor
		light.texture = glow
		light.texture_scale = 1.05
		light.color = Color(1.0, 0.72, 0.36)
		light.blend_mode = Light2D.BLEND_MODE_ADD
		if world.night_light_positions.find(anchor) >= 4:
			var lantern: Sprite2D = Sprite2D.new()
			lantern.texture = preload("res://assets/Outdoor decoration/Lantern.png")
			lantern.position = anchor
			add_child(lantern)
		add_child(light)
		lights.append(light)
	# The land sign moves with each purchase: its light follows the sprite.
	if world.land != null:
		var light: PointLight2D = PointLight2D.new()
		light.texture = glow
		light.texture_scale = 0.55
		light.color = Color(1.0, 0.78, 0.4)
		light.blend_mode = Light2D.BLEND_MODE_ADD
		world.land.sign.add_child(light)
		lights.append(light)

func refresh(timestamp: float, weather_tint: Color) -> void:
	var daylight: Color = daylight_color(timestamp)
	ambient.color = daylight * weather_tint
	darkness = clampf((1.0 - daylight.b) / 0.55, 0.0, 1.0)
	# Warm dusk still needs lamps; midday does not.
	darkness = maxf(darkness, clampf((1.0 - daylight.g) / 0.75, 0.0, 1.0))
	for light: PointLight2D in lights:
		light.energy = darkness * 0.85
		light.enabled = darkness > 0.01 and light.get_parent().is_visible_in_tree()

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	if darkness <= 0.01 or world.apiary == null or world.weather.current_weather == WeatherManager.Weather.RAIN:
		return
	for garden: FlowerGarden in world.apiary.gardens:
		for index: int in range(12):
			var phase: float = _phase * 0.65 + index * 2.399
			var point: Vector2 = to_local(garden.to_global(Vector2(192 + sin(phase * 0.7 + index) * 158, 128 + cos(phase * 0.83) * 91)))
			var alpha: float = darkness * (0.25 + 0.75 * pow(0.5 + 0.5 * sin(phase * 2.0), 3))
			draw_circle(point, 2.5, Color(0.84, 1.0, 0.22, alpha * 0.13))
			draw_rect(Rect2(point.round(), Vector2.ONE), Color(0.91, 1.0, 0.34, alpha))
