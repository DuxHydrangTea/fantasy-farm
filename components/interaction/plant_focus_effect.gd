extends Node
## A single translucent overlay follows the plant's texture and wind deformation.
const SHADER: Shader = preload("res://shaders/plant_focus.gdshader")
const PARAMETERS: Array[StringName] = [&"plant_height", &"amplitude", &"speed", &"anchor_visible_root", &"ground_y"]
var source: Node2D
var overlay: Sprite2D
var material: ShaderMaterial
var _focused: bool = false
var _fade: Tween

func setup(plant: Node2D) -> void:
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
	if source is AnimatedSprite2D:
		var animated: AnimatedSprite2D = source as AnimatedSprite2D
		if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation) or animated.sprite_frames.get_frame_count(animated.animation) <= animated.frame:
			overlay.texture = null
			return
		overlay.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		overlay.centered = animated.centered
		overlay.offset = animated.offset
		overlay.flip_h = animated.flip_h
		overlay.flip_v = animated.flip_v
	else:
		var sprite: Sprite2D = source as Sprite2D
		if sprite == null:
			return
		overlay.texture = sprite.texture
		overlay.centered = sprite.centered
		overlay.offset = sprite.offset
		overlay.flip_h = sprite.flip_h
		overlay.flip_v = sprite.flip_v
		overlay.region_enabled = sprite.region_enabled
		overlay.region_rect = sprite.region_rect
		overlay.hframes = sprite.hframes
		overlay.vframes = sprite.vframes
		overlay.frame = sprite.frame
	var wind: ShaderMaterial = source.material as ShaderMaterial
	if wind != null and wind.shader != null and wind.shader.resource_path == "res://shaders/plant_wind.gdshader":
		for parameter: StringName in PARAMETERS:
			material.set_shader_parameter(parameter, wind.get_shader_parameter(parameter))
	else:
		material.set_shader_parameter(&"amplitude", 0.0)
