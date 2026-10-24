class_name FarmGrassField
extends GrassChunkField
## G4 world adapter. This is the sole added grass node; transfer/feed are plain data.
const LIT_SHADER: Shader = preload("res://shaders/grass_farm.gdshader")
const FARM_DATA = preload("res://resources/grass/farm_grass_data.gd")
var world: FarmWorld
var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
var active: bool = false
var wanted: bool = true
var fallback_reason: String = ""
var _last_wind: float = -1.0

func _ready() -> void:
	sort_root = world
	field_shader = LIT_SHADER
	interaction_enabled = true
	enabled = false # No RID drawing before preflight and source transaction commit.
	catalog.types.assign(FARM_DATA.TYPES)
	catalog.texture = load(GrassSourceTransfer.SOURCE) as Texture2D
	# Canvas rects and QuadMesh use opposite diagonals. Match Canvas rects so
	# nearest sampling resolves exact texel boundaries consistently at odd zoom.
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(16, 16)
	var arrays: Array = quad.surface_get_arrays(0)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([3, 1, 0, 2, 3, 0])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	renderer.mesh_override = mesh
	samples = transfer.prepare(world.get_node_or_null("TinyDecor") as TileMapLayer, world, world.grass_trial_region)
	if catalog.texture == null:
		samples.clear() # Keep source cells if an imported atlas cannot be loaded.
	wanted = world.gpu_grass_enabled
	super._ready()
	effect.set_shader_parameter(&"animate_frames", false)
	var regions: PackedVector4Array = PackedVector4Array()
	for row: Dictionary in FARM_DATA.TYPES:
		regions.append(Vector4(float(row.source_region[0]) / 144.0, float(row.source_region[1]) / 416.0, 16.0 / 144.0, 16.0 / 416.0))
	effect.set_shader_parameter(&"farm_source_regions", regions)
	effect.set_shader_parameter(&"wind_direction", Vector2(100, 18).normalized())
	if not world.objectives.progress.restored.is_connected(_after_restore):
		world.objectives.progress.restored.connect(_after_restore)
	set_conversion(wanted)

func _after_restore() -> void:
	# A short save/load teleport must not be interpreted as ordinary walking.
	interactions.reset_all_motion()

func render_preflight() -> String:
	if DisplayServer.get_name() == "headless":
		return "Headless renderer: authored grass retained"
	if catalog.texture == null or catalog.texture.get_size() != Vector2(144, 416):
		return "Grass atlas unavailable"
	if field_shader == null:
		return "Grass shader unavailable"
	var uniforms: Array = field_shader.get_shader_uniform_list()
	var names: Array[StringName] = []
	for uniform: Dictionary in uniforms:
		names.append(StringName(uniform.name))
	if not &"actor_count" in names or not &"wind_strength" in names:
		return "Grass shader schema unavailable"
	return ""

func set_conversion(value: bool) -> bool:
	wanted = value
	if not value:
		_fallback("")
		return true
	var reason: String = render_preflight()
	if not reason.is_empty() or samples.is_empty():
		_fallback(reason if not reason.is_empty() else "No eligible grass in trial region")
		return false
	set_enabled(true)
	update_view()
	interactions.tick(0.0, _world_view, effect, true)
	if not renderer.last_error.is_empty() or not interactions.last_error.is_empty():
		_fallback(renderer.last_error if not renderer.last_error.is_empty() else interactions.last_error)
		return false
	if not transfer.suppress():
		_fallback("Authored source changed before grass transaction committed")
		return false
	active = true
	fallback_reason = ""
	_sync_environment()
	return true

func _fallback(reason: String) -> void:
	set_enabled(false)
	renderer.clear()
	_last_region = Rect2i(0, 0, -1, -1)
	transfer.restore()
	active = false
	fallback_reason = reason

func _sync_environment() -> void:
	var effects: WeatherEffects = world.weather.effects
	var values: Array[float] = [0.65, 1.2, 1.0, 2.8]
	var amplitude: float = lerpf(0.65, values[int(effects.active_weather)], effects.strength)
	if absf(amplitude - _last_wind) > 0.002:
		_last_wind = amplitude
		set_wind(amplitude)

func _process(delta: float) -> void:
	_sync_environment()
	super._process(delta)
	if not renderer.last_error.is_empty() or not interactions.last_error.is_empty():
		_fallback(renderer.last_error if not renderer.last_error.is_empty() else interactions.last_error)

func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		set_conversion(not active)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(world.objectives) and world.objectives.progress.restored.is_connected(_after_restore):
		world.objectives.progress.restored.disconnect(_after_restore)
	transfer.restore()
	active = false
	super._exit_tree()
