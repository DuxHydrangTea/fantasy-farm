class_name PollinationComponent
extends RefCounted
## Chọn nguồn hoa đại diện từ các nguồn đã được phân cho một tổ.
## Ưu tiên hệ số mật, sau đó số lượng, khoảng cách và mã nguồn.

## Các nguồn đã phân cho tổ, mỗi bản ghi có type, name và point.
var sources: Array[Dictionary] = []
## Mã nguồn được chọn, rỗng khi không có nguồn.
var source_id: String = ""
## Tên nguồn được chọn.
var source_name: String = ""
## Vị trí nguồn gần nhất thuộc loại được chọn.
var source_point: Vector2
## Số nguồn cùng loại được chọn.
var source_count: int = 0

## Tính lại nguồn đại diện quanh origin. Khi legacy bật, mọi loại có cùng
## thứ hạng tốc độ và được phân giải bằng số lượng, khoảng cách và mã.
func resolve(origin: Vector2, rules: BeehiveDefinition = null, legacy: bool = false) -> void:
	source_id = ""
	source_name = ""
	source_count = 0
	var counts: Dictionary = {}
	var closest: Dictionary = {}
	for source: Dictionary in sources:
		var key: String = source.type
		counts[key] = int(counts.get(key,0)) + 1
		if not closest.has(key) or origin.distance_squared_to(source.point) < origin.distance_squared_to(closest[key].point):
			closest[key] = source
	var distance: float = INF
	var priority: float = -1.0
	for key: String in counts:
		var candidate: float = origin.distance_squared_to(closest[key].point)
		var rank: float = rules.honey_rate(key) if rules != null and not legacy else 1.0
		if rank > priority or (is_equal_approx(rank, priority) and (int(counts[key]) > source_count or (int(counts[key]) == source_count and (candidate < distance or (is_equal_approx(candidate,distance) and key < source_id))))):
			source_id = key
			source_name = closest[key].name
			source_point = closest[key].point
			source_count = int(counts[key])
			distance = candidate
			priority = rank

## Cho biết đã chọn được nguồn có mã không rỗng.
func active() -> bool:
	return not source_id.is_empty()
