class_name GrassTileMaterials
extends RefCounted
## Preserve mixed-row draw order: overlapping grass bends inside TileMap itself.
const SHADER: Shader = preload("res://shaders/grass_tilemap.gdshader")
const DATA = preload("res://resources/grass/farm_grass_data.gd")
var materials: Array[ShaderMaterial] = []
var _layer: WeakRef
var _original: TileSet
var _local: TileSet
var _previous: Dictionary = {}

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
