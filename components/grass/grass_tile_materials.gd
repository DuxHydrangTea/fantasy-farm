class_name GrassTileMaterials
extends RefCounted
## Gắn shader vào các tile cỏ giữ lại trong TileMap để bảo toàn thứ tự vẽ.
## TileSet được sao chép cục bộ và material được dùng chung theo loại tile.

## Shader biến dạng cỏ trong TileMap.
const SHADER: Shader = preload("res://shaders/grass_tilemap.gdshader")
## Dữ liệu vùng nguồn và gốc cỏ.
const DATA = preload("res://resources/grass/farm_grass_data.gd")
## Các material đã cài.
var materials: Array[ShaderMaterial] = []
var _layer: WeakRef
var _original: TileSet
var _local: TileSet
var _previous: Dictionary = {}

## Sao chép TileSet, gắn material vào các tile cỏ không có material và áp lên layer.
## Trả true nếu có ít nhất một material hoặc đã cài trước đó.
func install(layer: TileMapLayer) -> bool:
	if not materials.is_empty():
		return true
	_original = layer.tile_set
	_local = _original.duplicate(true) as TileSet
	if _local == null:
		return false
	for id: int in range(_local.get_source_count()):
		var source: TileSetSource = _local.get_source(_local.get_source_id(id))
		if not source is TileSetAtlasSource or source.texture == null or source.texture.resource_path != GrassSourceTransfer.SOURCE:
			continue
		for row: Dictionary in DATA.TYPES:
			var coords: Vector2i = Vector2i(row.coords[0], row.coords[1])
			if not source.has_tile(coords):
				continue
			var tile: TileData = source.get_tile_data(coords, 0)
			if tile.material != null:
				continue
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter(&"tile_source_pixel", Vector2(row.source_region[0], row.source_region[1]))
			material.set_shader_parameter(&"tile_root_pixel", float(row.root_y))
			material.set_shader_parameter(&"tile_size_pixel", Vector2(row["size"][0], row["size"][1]))
			tile.material = material
			materials.append(material)
	_layer = weakref(layer)
	layer.tile_set = _local
	return not materials.is_empty()

## Đồng bộ các shader parameter gió và actor đã thay đổi từ material chung.
func sync_from(effect: ShaderMaterial) -> void:
	# Share per species, never per cell; upload only uniforms that changed.
	if materials.is_empty():
		return
	for key: StringName in [&"wind_strength", &"wind_direction", &"use_test_time", &"test_time", &"actor_count", &"actor_segments", &"actor_parameters", &"interaction_clock"]:
		var value: Variant = effect.get_shader_parameter(key)
		if _previous.has(key) and _previous[key] == value:
			continue
		_previous[key] = value
		for material: ShaderMaterial in materials:
			material.set_shader_parameter(key, value)

## Khôi phục TileSet gốc nếu layer vẫn dùng bản sao do component cài.
func restore() -> void:
	if _layer != null:
		var layer: TileMapLayer = _layer.get_ref() as TileMapLayer
		if layer != null and layer.tile_set == _local:
			layer.tile_set = _original
	materials.clear()
	_previous.clear()
	_layer = null
	_original = null
	_local = null
