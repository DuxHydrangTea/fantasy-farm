extends RefCounted
## Gắn shader gió và tương tác cho sprite, tile cây cỏ trang trí phù hợp.
## Material được chia sẻ theo vùng atlas; vị trí và thứ tự vẽ gốc được giữ.

## Shader chuyển động cây cỏ.
const SHADER: Shader = preload("res://shaders/decor_foliage.gdshader")
## Dữ liệu nhận diện vùng cỏ trong atlas.
const DATA = preload("res://resources/grass/farm_grass_data.gd")
## Texture hoa trang trí.
const FLOWERS: String = "res://assets/Outdoor decoration/Flowers.png"
## Các shader parameter đồng bộ từ nguồn tương tác cỏ.
const KEYS: Array[StringName] = [&"wind_strength", &"wind_direction", &"use_test_time", &"test_time", &"actor_count", &"actor_segments", &"actor_parameters", &"interaction_clock"]
## Danh sách material đã tạo.
var materials: Array[ShaderMaterial] = []
## Số sprite được gắn material.
var sprite_count: int = 0
## Số loại tile được gắn material.
var tile_count: int = 0
var _cache: Dictionary = {}
var _images: Dictionary = {}
var _previous: Dictionary = {}
var _sprites: Array[Dictionary] = []
var _layers: Array[Dictionary] = []

## Khôi phục lần cài trước rồi quét sprite và TileMapLayer dưới root.
## Bỏ qua layer đã chuyển sang batch cỏ và node có material riêng.
func install(root: Node, converted_layer: TileMapLayer = null) -> void:
	restore()
	for node: Node in root.find_children("*", "Sprite2D", true, false):
		var sprite: Sprite2D = node as Sprite2D
		if sprite.texture == null or sprite.material != null or sprite.use_parent_material or not bool(sprite.get_meta(&"foliage_motion", true)):
			continue
		var region: Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
		region.size /= Vector2(sprite.hframes, sprite.vframes)
		region.position += Vector2(sprite.frame_coords) * region.size
		var axis: Vector2 = Vector2(-1 if sprite.flip_h else 1, -1 if sprite.flip_v else 1)
		var material: ShaderMaterial = _material(sprite.texture, Rect2i(region), axis)
		if material == null:
			continue
		_sprites.append({"node": weakref(sprite), "material": material})
		sprite.material = material
		sprite_count += 1
	for node: Node in root.find_children("*", "TileMapLayer", true, false):
		var layer: TileMapLayer = node as TileMapLayer
		if layer == converted_layer or layer.tile_set == null or layer.material != null or layer.use_parent_material or not bool(layer.get_meta(&"foliage_motion", true)):
			continue
		_install_layer(layer)
	_images.clear()

func _install_layer(layer: TileMapLayer) -> void:
	var chosen: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		var source_id: int = layer.get_cell_source_id(cell)
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		var key: Vector3i = Vector3i(source_id, coords.x, coords.y)
		if chosen.has(key) or layer.get_cell_alternative_tile(cell) != 0:
			continue
		var source: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null or source.get_tile_animation_frames_count(coords) != 1:
			continue
		var tile: TileData = source.get_tile_data(coords, 0)
		if tile.material != null or tile.flip_h or tile.flip_v or tile.transpose:
			continue
		var material: ShaderMaterial = _material(source.texture, source.get_tile_texture_region(coords))
		if material != null:
			chosen[key] = material
	if chosen.is_empty():
		return
	var original: TileSet = layer.tile_set
	var local: TileSet = original.duplicate(true) as TileSet
	for key: Vector3i in chosen:
		var source: TileSetAtlasSource = local.get_source(key.x) as TileSetAtlasSource
		source.get_tile_data(Vector2i(key.y, key.z), 0).material = chosen[key]
		tile_count += 1
	_layers.append({"node": weakref(layer), "original": original, "local": local})
	layer.tile_set = local

func _tree_texture(path: String) -> bool:
	if not path.begins_with("res://assets/Trees/"):
		return false
	var file: String = path.get_file()
	return file.begins_with("Big_") or file.begins_with("Medium_") or file.begins_with("Small_") or (path.contains("/OakStyle/") and (file.begins_with("birch_") or file.begins_with("maple_") or file.begins_with("willow_")))

func _eligible(path: String, region: Rect2i) -> bool:
	if path == GrassSourceTransfer.SOURCE:
		for row: Dictionary in DATA.TYPES:
			if region == Rect2i(row.source_region[0], row.source_region[1], row["size"][0], row["size"][1]):
				return true
		return false
	if path == FLOWERS:
		# The right half contains pots; their separate flower visuals own motion.
		return region.size == Vector2i(16, 16) and region.position.x >= 0 and region.end.x <= 80 and region.position.y >= 0 and region.end.y <= 160
	return _tree_texture(path)

func _material(texture: Texture2D, region: Rect2i, axis: Vector2 = Vector2.ONE) -> ShaderMaterial:
	var path: String = texture.resource_path
	if not _eligible(path, region):
		return null
	var key: String = path + str(region) + str(axis)
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	if not _images.has(path):
		_images[path] = texture.get_image()
	var image: Image = _images[path] as Image
	if image == null or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
		return null
	var bounds: Rect2i = image.get_region(region).get_used_rect()
	if bounds.size == Vector2i.ZERO:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"atlas_size", texture.get_size())
	material.set_shader_parameter(&"source_pixel", Vector2(region.position))
	material.set_shader_parameter(&"sprite_size", Vector2(region.size))
	material.set_shader_parameter(&"root_pixel", float(bounds.end.y))
	material.set_shader_parameter(&"uv_axis", axis)
	material.set_shader_parameter(&"motion_gain", 0.35 if _tree_texture(path) else 1.0)
	materials.append(material)
	_cache[key] = material
	return material

## Đồng bộ các tham số gió và actor thay đổi vào material đã tạo.
func sync_from(effect: ShaderMaterial) -> void:
	for key: StringName in KEYS:
		var value: Variant = effect.get_shader_parameter(key)
		if _previous.has(key) and _previous[key] == value:
			continue
		_previous[key] = value
		for material: ShaderMaterial in materials:
			material.set_shader_parameter(key, value)

## Khôi phục material sprite và TileSet chỉ khi chúng vẫn là bản đã cài.
func restore() -> void:
	for entry: Dictionary in _sprites:
		var sprite: Sprite2D = entry.node.get_ref() as Sprite2D
		if sprite != null and sprite.material == entry.material:
			sprite.material = null
	for entry: Dictionary in _layers:
		var layer: TileMapLayer = entry.node.get_ref() as TileMapLayer
		if layer != null and layer.tile_set == entry.local:
			layer.tile_set = entry.original
	_sprites.clear()
	_layers.clear()
	_cache.clear()
	_images.clear()
	_previous.clear()
	materials.clear()
	sprite_count = 0
	tile_count = 0
