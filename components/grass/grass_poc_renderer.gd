class_name GrassPocRenderer
extends RefCounted
## Tạo một batch MultiMesh cỏ và CanvasItem từ danh sách mẫu.
## Phân chunk và thứ tự Y-sort do GrassChunkRenderer và GrassChunkIndex quản lý.

## RID CanvasItem được cấp phát.
var canvas: RID
## MultiMesh chứa transform và dữ liệu riêng từng instance.
var instances: MultiMesh
## Biên hình học cục bộ của batch.
var bounds: Rect2
var _material: ShaderMaterial
var _texture: Texture2D

## Giải phóng batch cũ rồi dựng batch mới dưới CanvasItem cha.
## Mỗi mẫu chứa loại, transform và pha tùy chọn; mesh rỗng dùng quad 16×16.
func build(parent: RID, catalog: GrassSourceCatalog, samples: Array[Dictionary], effect: ShaderMaterial, geometry: Mesh = null) -> void:
	clear()
	if samples.is_empty():
		return
	_material = effect
	_texture = catalog.texture
	var mesh: Mesh = geometry
	if mesh == null:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(16, 16)
		mesh = quad
	instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = samples.size()
	var first: bool = true
	for index: int in range(samples.size()):
		var sample: Dictionary = samples[index]
		var transform: Transform2D = sample.transform
		var type: int = int(sample.type)
		instances.set_instance_transform_2d(index, transform)
		instances.set_instance_custom_data(index, Color(float(type), float(catalog.source(type).root_y), float(sample.get("phase", 0.0)), 1.0))
		var rect: Rect2 = catalog.local_bounds(type)
		for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var local: Vector2 = transform * point
			if first:
				bounds = Rect2(local, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(local)
	canvas = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(canvas, parent)
	RenderingServer.canvas_item_set_material(canvas, effect.get_rid())
	RenderingServer.canvas_item_add_multimesh(canvas, instances.get_rid(), catalog.texture.get_rid())

## Đặt custom rect để culling bao gồm khoảng dự phòng cho hiệu ứng.
func update_bounds(margin: float) -> void:
	if canvas.is_valid():
		RenderingServer.canvas_item_set_custom_rect(canvas, true, bounds.grow(margin))

## Giải phóng RID và tham chiếu tài nguyên batch.
func clear() -> void:
	if canvas.is_valid():
		RenderingServer.free_rid(canvas)
	canvas = RID()
	instances = null
	_material = null
	_texture = null
	bounds = Rect2()
