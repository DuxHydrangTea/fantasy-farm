@tool
class_name AnimalPen
extends Node2D
## Chuồng giới hạn vùng sống, loài và sức chứa, đồng thời sở hữu kho sản phẩm.
## Mô phỏng offline được tạo khi cần để đồng bộ cả đàn trước các thay đổi.

## Lịch thời tiết dùng trong mô phỏng nhu cầu.
var weather: WeatherSchedule
## Cầu nối mô phỏng offline của chuồng.
var offline_simulation: PenOfflineSimulation
## Script kho sản phẩm chuồng.
const ProduceStorage = preload("res://components/animals/pen_produce_storage.gd")
## Bộ đệm sản phẩm dùng chung.
var produce_storage: RefCounted = ProduceStorage.new()
## Điểm tương tác thu sản phẩm.
var produce_access: Node2D
## Bật lưu và thu sản phẩm qua kho chung.
var produce_storage_enabled: bool = false

## Mã ổn định của chuồng trong save.
@export var persistent_id: StringName
## Các loài được phép mua vào chuồng. Đổi sức chứa không tự xóa con vật hiện có.
@export var accepted_species: Array[AnimalTypes.Species] = []
## Số vật nuôi tối đa khi thêm mới.
@export_range(1, 200) var capacity: int = 30
## Biên vùng di chuyển trong tọa độ cục bộ chuồng.
@export var bounds: Rect2 = Rect2(0, 0, 384, 256):
	set(value):
		if value is Rect2:
			bounds = value.abs()
			queue_redraw()

## Tiến mô phỏng cả đàn đến timestamp, tùy chọn buộc xử lý khoảng ngắn.
func advance_offline(timestamp: float, force: bool = false) -> bool:
	if offline_simulation == null:
		offline_simulation = (PenOfflineSimulation as Variant).new(self)
	return offline_simulation.advance(timestamp, force)

## Chốt trạng thái đàn đến timestamp trước khi thay đổi chuồng hoặc nguồn cung.
func sync_before_change(timestamp: float) -> void:
	if offline_simulation == null:
		offline_simulation = (PenOfflineSimulation as Variant).new(self)
	offline_simulation.sync_before_change(timestamp)

## Đồng bộ rồi thu sản phẩm từ kho vào túi, tùy chọn lọc mã; trả số thực chuyển.
func collect_stored_produce(inventory: InventoryComponent, timestamp: float, item_id: StringName = &"") -> int:
	if not produce_storage_enabled:
		return 0
	sync_before_change(timestamp)
	return produce_storage.collect(inventory, item_id)

## Biên cục bộ sau khi lùi vào margin không âm, không thu quá tâm.
func allowed_bounds(margin: float = 0.0) -> Rect2:
	var inset: Vector2 = Vector2.ONE * maxf(0.0, margin)
	inset = inset.min(bounds.size * 0.5)
	return Rect2(bounds.position + inset, bounds.size - inset * 2.0)

## Kiểm tra điểm toàn cục nằm trong biên sau khi trừ margin, có dung sai số thực.
func contains_world(point: Vector2, margin: float = 0.0) -> bool:
	var local: Vector2 = to_local(point)
	var area: Rect2 = allowed_bounds(margin)
	# Transform round trips can move an edge point by a few floating-point ULPs.
	return local.x >= area.position.x - 0.0001 and local.x <= area.end.x + 0.0001 and local.y >= area.position.y - 0.0001 and local.y <= area.end.y + 0.0001

## Kẹp điểm toàn cục vào biên chuồng sau khi trừ margin.
func clamp_world(point: Vector2, margin: float = 0.0) -> Vector2:
	var area: Rect2 = allowed_bounds(margin)
	return to_global(to_local(point).clamp(area.position, area.end))

## Lấy điểm ngẫu nhiên toàn cục trong biên sau khi trừ margin.
func sample_world(rng: RandomNumberGenerator, margin: float = 0.0) -> Vector2:
	var area: Rect2 = allowed_bounds(margin)
	return to_global(Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)))

func _draw() -> void:
	if Engine.is_editor_hint() and bounds is Rect2:
		draw_rect(bounds, Color(0.4, 0.9, 0.7, 0.08))
		draw_rect(bounds, Color(0.4, 0.9, 0.7, 0.8), false, 1.0)
