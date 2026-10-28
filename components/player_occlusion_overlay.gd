extends AnimatedSprite2D
## A separate transparent GPU viewport contains only real foreground occluders.
## Screen colours, UI, grass and lighting never participate in this mask.
@export var source: AnimatedSprite2D
@export var tree_layer_names: Array[StringName] = [&"Tree", &"Trees"]
const MASK_SIZE: Vector2i = Vector2i(64, 96)
var _mask_view: SubViewport
var _sprites: Array[Sprite2D] = []
var _tree_layers: Array[TileMapLayer] = []
var _pool: Array[Sprite2D] = []
var _used: int = 0
var _refresh_timer: float = 0.0
var _world: Node2D

func _ready() -> void:
	hide()
	if not is_instance_valid(source):
		return
	_world = source.get_parent().get_parent() as Node2D
	_mask_view = SubViewport.new()
	_mask_view.name = "ForegroundMask"
	_mask_view.size = MASK_SIZE
	_mask_view.transparent_bg = true
	_mask_view.disable_3d = true
	_mask_view.gui_disable_input = true
	_mask_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask_view)
	material = material.duplicate()
	(material as ShaderMaterial).set_shader_parameter(&"occlusion_mask", _mask_view.get_texture())
	RenderingServer.frame_pre_draw.connect(_update_mask)

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0 and is_instance_valid(_world):
		_refresh_timer = 0.5
		_sprites.clear()
		_tree_layers.clear()
		_collect(_world)

func _collect(node: Node) -> void:
	if node == source.get_parent() or node is CanvasLayer or node is Control:
		return
	if node is TileMapLayer:
		var layer: TileMapLayer = node as TileMapLayer
		if tree_layer_names.has(layer.name):
			_tree_layers.append(layer)
		return
	if node is Crop:
		_sprites.append((node as Crop).sprite)
		return
	if node is PerennialTree:
		_sprites.append((node as PerennialTree).sprite)
		return
	# Authored buildings, gates and landmark trees own a direct Sprite2D.
	if node is StaticBody2D:
		for child: Node in node.get_children():
			if child is Sprite2D:
				_sprites.append(child as Sprite2D)
		return
	for child: Node in node.get_children():
		_collect(child)

func _update_mask() -> void:
	if not is_instance_valid(source) or not is_instance_valid(_mask_view):
		return
	_used = 0
	if source.is_visible_in_tree():
		sprite_frames = source.sprite_frames
		animation = source.animation
		frame = source.frame
		flip_h = source.flip_h
		flip_v = source.flip_v
		transform = source.transform
		offset = source.offset
		centered = source.centered
		var origin: Vector2 = (source.global_position - Vector2(MASK_SIZE) * 0.5).floor()
		_mask_view.canvas_transform = Transform2D(0, -origin)
		(material as ShaderMaterial).set_shader_parameter(&"mask_rect", Vector4(origin.x, origin.y, MASK_SIZE.x, MASK_SIZE.y))
		var area: Rect2 = Rect2(origin, Vector2(MASK_SIZE))
		for visual: Sprite2D in _sprites:
			if not is_instance_valid(visual) or visual.texture == null or not visual.is_visible_in_tree():
				continue
			if not _in_front(visual) or not (visual.global_transform * visual.get_rect()).grow(4.0).intersects(area):
				continue
			var copy: Sprite2D = _next_sprite()
			copy.texture = visual.texture
			copy.transform = visual.global_transform
			copy.centered = visual.centered
			copy.offset = visual.offset
			copy.hframes = visual.hframes
			copy.vframes = visual.vframes
			copy.frame = visual.frame
			copy.flip_h = visual.flip_h
			copy.flip_v = visual.flip_v
			copy.region_enabled = visual.region_enabled
			copy.region_rect = visual.region_rect
			copy.region_filter_clip_enabled = visual.region_filter_clip_enabled
			# Same MODEL_MATRIX and TIME preserve the original plant wind deformation.
			copy.material = visual.material
			copy.modulate = Color(1, 1, 1, _opacity(visual))
		for layer: TileMapLayer in _tree_layers:
			_draw_tree_tiles(layer, area)
	for index: int in range(_used, _pool.size()):
		_pool[index].hide()
	visible = source.is_visible_in_tree() and _used > 0

func _next_sprite() -> Sprite2D:
	if _used == _pool.size():
		var copy: Sprite2D = Sprite2D.new()
		copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mask_view.add_child(copy)
		_pool.append(copy)
	var result: Sprite2D = _pool[_used]
	_used += 1
	result.show()
	return result

func _in_front(visual: Node2D) -> bool:
	var player: Node2D = source.get_parent() as Node2D
	var visual_z: int = _effective_z(visual)
	var player_z: int = _effective_z(source)
	if visual_z != player_z:
		return visual_z > player_z
	var anchor: Node2D = visual
	var ancestor: Node = visual.get_parent()
	while ancestor != _world and ancestor is Node2D:
		if not (ancestor as Node2D).y_sort_enabled:
			anchor = ancestor as Node2D
		ancestor = ancestor.get_parent()
	# Equal Y alone is not evidence of being in front; avoid order-dependent flashes.
	return anchor.global_position.y > player.global_position.y

func _effective_z(item: CanvasItem) -> int:
	var result: int = item.z_index
	var ancestor: CanvasItem = item.get_parent() as CanvasItem
	while item.z_as_relative and ancestor != null:
		result += ancestor.z_index
		item = ancestor
		ancestor = item.get_parent() as CanvasItem
	return result

func _opacity(item: CanvasItem) -> float:
	var result: float = item.self_modulate.a
	while item != null:
		result *= item.modulate.a
		item = item.get_parent() as CanvasItem
	return result

func _draw_tree_tiles(layer: TileMapLayer, area: Rect2) -> void:
	if not is_instance_valid(layer) or not layer.is_visible_in_tree() or layer.tile_set == null:
		return
	for cell: Vector2i in layer.get_used_cells():
		var data: TileData = layer.get_cell_tile_data(cell)
		if data == null:
			continue
		var tile_z: int = _effective_z(layer) + data.z_index
		var player_z: int = _effective_z(source)
		var origin: Vector2 = layer.map_to_local(cell)
		var sort_y: float = layer.to_global(origin + Vector2(0, data.y_sort_origin + layer.y_sort_origin)).y
		if tile_z < player_z or (tile_z == player_z and (not layer.y_sort_enabled or sort_y <= source.get_parent().global_position.y)):
			continue
		var atlas: TileSetAtlasSource = layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
		if atlas == null:
			continue
		var region: Rect2i = atlas.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
		var tile_transform: Transform2D = layer.global_transform * Transform2D(0, origin - Vector2(data.texture_origin))
		var bounds: Rect2 = tile_transform * Rect2(-Vector2(region.size) * 0.5, Vector2(region.size))
		if not bounds.intersects(area):
			continue
		var copy: Sprite2D = _next_sprite()
		copy.texture = atlas.texture
		copy.hframes = 1
		copy.vframes = 1
		copy.frame = 0
		copy.centered = true
		copy.offset = Vector2.ZERO
		copy.region_enabled = true
		copy.region_rect = Rect2(region)
		copy.region_filter_clip_enabled = true
		var alternative: int = layer.get_cell_alternative_tile(cell)
		copy.flip_h = data.flip_h != bool(alternative & TileSetAtlasSource.TRANSFORM_FLIP_H)
		copy.flip_v = data.flip_v != bool(alternative & TileSetAtlasSource.TRANSFORM_FLIP_V)
		if data.transpose != bool(alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE):
			tile_transform = tile_transform * Transform2D(Vector2(0, 1), Vector2(1, 0), Vector2.ZERO)
		copy.transform = tile_transform
		copy.material = layer.material
		copy.modulate = Color(1, 1, 1, _opacity(layer) * data.modulate.a)
