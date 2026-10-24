class_name GrassField
extends Node2D
## One scene node, static GPU instances, zero process/physics callbacks per tuft.
## G1 POC only: no actor feed, chunks or modifications to authored map cells.
const SHADER: Shader = preload("res://shaders/grass_field.gdshader")
@export_range(1, 500) var tuft_count: int = 324
@export_range(1, 50) var columns: int = 18
@export var spacing: Vector2 = Vector2(24, 22)
@export_range(0.0, 6.0) var wind_strength: float = 0.85
@export var wind_direction: Vector2 = Vector2.RIGHT
@export var animate_frames: bool = true
var catalog: GrassSourceCatalog = GrassSourceCatalog.new()
var renderer: GrassPocRenderer = GrassPocRenderer.new()
var effect: ShaderMaterial
var samples: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_notify_transform(true)
	effect = ShaderMaterial.new()
	effect.shader = SHADER
	set_wind(wind_strength, wind_direction)
	set_animation(animate_frames)
	if samples.is_empty():
		for index: int in range(tuft_count):
			var row: int = floori(float(index) / float(columns))
			var origin: Vector2 = Vector2(index % columns, row) * spacing
			samples.append({"type": row % catalog.size(), "transform": Transform2D(0.0, origin), "phase": float(index % 17) / 17.0})
	set_samples(samples)

func set_samples(values: Array[Dictionary]) -> void:
	samples = values.duplicate()
	if effect == null:
		return
	renderer.build(get_canvas_item(), catalog, samples, effect)
	_refresh_bounds()

func set_wind(strength: float, direction: Vector2 = Vector2.RIGHT) -> void:
	wind_strength = clampf(strength, 0.0, 6.0)
	wind_direction = direction
	if effect != null:
		effect.set_shader_parameter(&"wind_strength", wind_strength)
		effect.set_shader_parameter(&"wind_direction", wind_direction)
	_refresh_bounds()

func set_animation(enabled: bool) -> void:
	animate_frames = enabled
	if effect != null:
		effect.set_shader_parameter(&"animate_frames", enabled)

func set_test_time(value: float, enabled: bool = true) -> void:
	effect.set_shader_parameter(&"use_test_time", enabled)
	effect.set_shader_parameter(&"test_time", value)

func _refresh_bounds() -> void:
	if not is_inside_tree():
		return
	var basis: Transform2D = get_global_transform()
	var minimum_scale: float = maxf(0.001, minf(basis.x.length(), basis.y.length()))
	renderer.update_bounds(wind_strength * 1.25 / minimum_scale)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and renderer != null:
		_refresh_bounds()

func _exit_tree() -> void:
	renderer.clear()
