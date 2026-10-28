extends Node
## A single translucent overlay follows the plant's texture and wind deformation.
const SHADER: Shader = preload("res://shaders/plant_focus.gdshader")
const PARAMETERS: Array[StringName] = [&"plant_height", &"amplitude", &"speed", &"anchor_visible_root", &"ground_y"]
var source: Sprite2D
var overlay: Sprite2D
var material: ShaderMaterial
var _focused: bool = false
var _fade: Tween

func setup(plant: Sprite2D) -> void:
	source = plant
	material = ShaderMaterial.new()
	material.shader = SHADER
	overlay = Sprite2D.new()
	overlay.name = "PlantFocusGlow"
	overlay.material = material
	overlay.z_index = 1
	overlay.modulate.a = 0.0
	source.add_child(overlay)
	_sync()
	set_process(false)

func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	if not is_instance_valid(overlay):
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_sync()
	set_process(true)
	_fade = create_tween()
	_fade.tween_property(overlay, "modulate:a", 0.14 if value else 0.0, 0.18)
	if not value:
		_fade.tween_callback(_stop_if_unfocused)

func _stop_if_unfocused() -> void:
	if not _focused:
		set_process(false)

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if not is_instance_valid(source) or not is_instance_valid(overlay):
		return
	overlay.texture = source.texture
	overlay.centered = source.centered
	overlay.offset = source.offset
	overlay.flip_h = source.flip_h
	overlay.flip_v = source.flip_v
	overlay.region_enabled = source.region_enabled
	overlay.region_rect = source.region_rect
	overlay.hframes = source.hframes
	overlay.vframes = source.vframes
	overlay.frame = source.frame
	var wind: ShaderMaterial = source.material as ShaderMaterial
	if wind != null and wind.shader != null and wind.shader.resource_path == "res://shaders/plant_wind.gdshader":
		for parameter: StringName in PARAMETERS:
			material.set_shader_parameter(parameter, wind.get_shader_parameter(parameter))
	else:
		material.set_shader_parameter(&"amplitude", 0.0)
