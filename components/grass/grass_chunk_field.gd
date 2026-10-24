class_name GrassChunkField
extends Node2D
## G2/G3 manager: indexed chunks and one shared actor feed, never per-tuft ticks.
const SHADER: Shader = preload("res://shaders/grass_field.gdshader")
@export var field_shader: Shader = SHADER
@export var sort_root: Node2D
@export_enum("256:256", "512:512") var chunk_size: int = 512
@export_range(0, 2) var reserve_chunks: int = 1
@export_range(1, 256) var max_resident_chunks: int = 64
@export_range(1, 500000) var max_resident_instances: int = 100000
@export_range(1, 8192) var max_resident_batches: int = 2048
@export_range(0.0, 6.0) var wind_strength: float = 0.85
@export var interaction_enabled: bool = false
@export_enum("30:30", "60:60") var interaction_hz: int = 60
var interactions: GrassInteractionFeed = GrassInteractionFeed.new()
var catalog: GrassSourceCatalog = GrassSourceCatalog.new()
var index: GrassChunkIndex = GrassChunkIndex.new()
var renderer: GrassChunkRenderer = GrassChunkRenderer.new()
var samples: Array[Dictionary] = []
var effect: ShaderMaterial
var enabled: bool = true
var index_builds: int = 0
var _last_region: Rect2i = Rect2i(0, 0, -1, -1)
var _sort_pose: Transform2D
var _local_pose: Transform2D
var _margin: float = 0.0
var _world_view: Rect2
var _was_shown: bool = false

func _ready() -> void:
	if sort_root == null:
		sort_root = get_parent() as Node2D
	assert(sort_root != null and sort_root.is_ancestor_of(self) and sort_root.y_sort_enabled,
		"Grass needs an ancestor Y-sort root shared with actors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect = ShaderMaterial.new()
	effect.shader = field_shader
	if interaction_enabled:
		interactions.attach(sort_root)
	if not visibility_changed.is_connected(_visibility):
		visibility_changed.connect(_visibility)
	rebuild()
	_visibility()

func set_samples(values: Array[Dictionary]) -> void:
	samples = values.duplicate(true)
	if is_node_ready():
		rebuild()

func rebuild() -> void:
	if effect == null:
		return
	renderer.clear()
	_local_pose = sort_root.global_transform.affine_inverse() * global_transform
	index.build(samples, catalog, chunk_size, _local_pose)
	index_builds += 1
	_sort_pose = sort_root.global_transform
	set_wind(wind_strength)
	_last_region = Rect2i(0, 0, -1, -1)
	update_view()

func set_wind(strength: float) -> void:
	wind_strength = clampf(strength, 0.0, 6.0)
	if effect == null:
		return
	effect.set_shader_parameter(&"wind_strength", wind_strength)
	# Conservative inverse-basis bound, including skew and nonuniform scale.
	var inverse: Transform2D = sort_root.global_transform.affine_inverse()
	var displacement: float = maxf(wind_strength * 1.25, 12.0 if interaction_enabled else 0.0)
	var next_margin: float = displacement * maxf(absf(inverse.x.x) + absf(inverse.y.x), absf(inverse.x.y) + absf(inverse.y.y))
	if is_equal_approx(_margin, next_margin):
		return
	_margin = next_margin
	renderer.update_bounds(_margin)
	_last_region = Rect2i(0, 0, -1, -1)

func set_enabled(value: bool) -> void:
	enabled = value
	_visibility()

func set_interactions_enabled(value: bool) -> void:
	interaction_enabled = value
	if effect == null:
		return
	if value:
		interactions.attach(sort_root)
	else:
		interactions.detach()
		effect.set_shader_parameter(&"actor_count", 0)
	set_wind(wind_strength)

func _visibility() -> void:
	var shown: bool = enabled and is_visible_in_tree()
	if shown and not _was_shown and interaction_enabled:
		interactions.reset_all_motion()
	_was_shown = shown
	renderer.show_field(shown)
	set_process(shown)
	if shown and effect != null:
		update_view()

func _process(delta: float) -> void:
	update_view()
	if interaction_enabled:
		interactions.upload_hz = interaction_hz
		interactions.tick(delta, _world_view, effect)

func update_view() -> void:
	if effect == null or not enabled or not is_visible_in_tree():
		return
	if _local_pose != sort_root.global_transform.affine_inverse() * global_transform:
		rebuild()
		return
	if _sort_pose != sort_root.global_transform:
		_sort_pose = sort_root.global_transform
		set_wind(wind_strength)
	var inverse: Transform2D = sort_root.get_global_transform_with_canvas().affine_inverse()
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var area: Rect2 = Rect2(inverse * viewport.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(viewport.end.x, viewport.position.y), viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
		area = area.expand(inverse * corner)
	select_view(area)
	if not interaction_enabled:
		return
	var world_pose: Transform2D = sort_root.global_transform
	_world_view = Rect2(world_pose * area.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		_world_view = _world_view.expand(world_pose * corner)
	var extent_scale: float = maxf(absf(world_pose.x.x) + absf(world_pose.y.x), absf(world_pose.x.y) + absf(world_pose.y.y))
	_world_view = _world_view.grow(index.extent * extent_scale + 12.0)

func select_view(area: Rect2) -> void:
	var region: Rect2i = index.cell_rect(area, _margin + float(reserve_chunks * chunk_size))
	if region == _last_region:
		return
	_last_region = region
	renderer.select(index, region, sort_root.get_canvas_item(), catalog, effect, _margin, max_resident_chunks, max_resident_instances, max_resident_batches)

func _exit_tree() -> void:
	_was_shown = false
	interactions.detach()
	if effect != null:
		effect.set_shader_parameter(&"actor_count", 0)
	renderer.clear()
	request_ready()
