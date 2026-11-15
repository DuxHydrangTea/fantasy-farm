class_name LandGrassCover
extends RefCounted
## Vẽ lớp cỏ phủ đất chưa mở và phần đang mở bằng bốn CanvasItem dùng chung material.
## Chuyển động gió và actor được xử lý trong shader.

## Shader tile cỏ.
const SHADER: Shader = preload("res://shaders/grass_tilemap.gdshader")
## Các tham số được đồng bộ từ material cỏ chính.
const KEYS: Array[StringName] = [&"wind_strength",&"wind_direction",&"use_test_time",&"test_time",&"actor_count",&"actor_segments",&"actor_parameters",&"interaction_clock"]
## Cho biết các tài nguyên vẽ đã được cài.
var active: bool = false
## Các material dùng chung theo vùng texture.
var materials: Array[ShaderMaterial] = []
## Các CanvasItem RID đã cấp phát.
var canvases: Array[RID] = []
## Số ô trong lớp nền hiện tại.
var base_count: int = 0
## Số ô trong lớp đang mở.
var reveal_count: int = 0
## Số lần dựng lại lớp nền.
var base_builds: int = 0
## Số lần dựng lại lớp đang mở.
var reveal_builds: int = 0
var _base_key: int = -1
var _reveal_key: Vector2i = Vector2i(-2,-2)
var _previous: Dictionary = {}

## Tạo material và CanvasItem cho land nếu kích thước tile và texture phù hợp.
func install(land: LandExpansionComponent) -> bool:
	if active:
		return true
	if land.farming.farmland.tile_set.tile_size != Vector2i(16,16):
		return false
	var image: Image = land.DECOR.get_image()
	if image == null or image.is_empty():
		return false
	for region: Rect2 in land.WEED_REGIONS:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter(&"tile_source_pixel",region.position)
		material.set_shader_parameter(&"tile_size_pixel",region.size)
		material.set_shader_parameter(&"tile_root_pixel",float(image.get_region(Rect2i(region)).get_used_rect().end.y))
		materials.append(material)
	for i: int in range(4):
		var canvas: RID = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(canvas,land.get_canvas_item())
		RenderingServer.canvas_item_set_material(canvas,materials[i%2].get_rid())
		RenderingServer.canvas_item_set_default_texture_filter(canvas,RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		canvases.append(canvas)
	active = true
	refresh(land)
	return true

## Dựng lại phần nền hoặc phần mở khi số khối hay tiến độ hiệu ứng thay đổi.
func refresh(land: LandExpansionComponent) -> void:
	if not active:
		return
	var blocks: int = land.state.unlocked_blocks
	if _base_key != blocks:
		_base_key = blocks
		for i: int in range(2):
			RenderingServer.canvas_item_clear(canvases[i])
		base_count = 0
		for index: int in range(blocks, LandExpansionState.BLOCK_COUNT):
			base_count += _draw_cells(land, LandExpansionState.block_rect(index), 0)
		base_builds += 1
	var key: Vector2i = Vector2i(land._reveal_block, land._revealed_rows)
	if key != _reveal_key:
		_reveal_key = key
		for i: int in range(2,4):
			RenderingServer.canvas_item_clear(canvases[i])
		reveal_count = 0
		if key.x >= 0:
			var block: Rect2i = LandExpansionState.block_rect(key.x)
			if key.y < block.size.y:
				reveal_count = _draw_cells(land, Rect2i(block.position + Vector2i(0, key.y), Vector2i(block.size.x, block.size.y - key.y)), 2)
		reveal_builds += 1

func _draw_cells(land: LandExpansionComponent, cells: Rect2i, offset: int) -> int:
	var count: int = 0
	var area: Rect2 = Rect2(land.farming.farmland.map_to_local(LandExpansionState.REGION.position)-Vector2(8,8),Vector2(LandExpansionState.REGION.size)*16.0).grow(12.0)
	for i: int in range(offset,offset+2):
		RenderingServer.canvas_item_set_custom_rect(canvases[i],cells.has_area(),area)
	for y: int in range(cells.position.y,cells.end.y):
		for x: int in range(cells.position.x,cells.end.x):
			var variant: int = (x+y)%2
			var corner: Vector2 = land.farming.farmland.map_to_local(Vector2i(x,y))-Vector2(8,8)
			RenderingServer.canvas_item_add_texture_rect_region(canvases[offset+variant],Rect2(corner,Vector2(16,16)),land.DECOR.get_rid(),land.WEED_REGIONS[variant])
			count += 1
	return count

## Đồng bộ tham số gió và actor đã thay đổi từ material cỏ chính.
func sync_from(effect: ShaderMaterial) -> void:
	if not active:
		return
	for key: StringName in KEYS:
		var value: Variant = effect.get_shader_parameter(key)
		if _previous.has(key) and _previous[key] == value:
			continue
		_previous[key] = value
		for material: ShaderMaterial in materials:
			material.set_shader_parameter(key,value)

## Giải phóng RID và đặt lại trạng thái, bộ đếm lớp phủ.
func clear() -> void:
	for canvas: RID in canvases:
		RenderingServer.free_rid(canvas)
	canvases.clear()
	materials.clear()
	_previous.clear()
	_base_key = -1
	_reveal_key = Vector2i(-2,-2)
	base_count = 0
	reveal_count = 0
	active = false
