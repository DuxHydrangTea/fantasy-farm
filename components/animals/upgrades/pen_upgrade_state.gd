class_name PenUpgradeState
extends RefCounted
## Theo dõi cấp chuồng, sức chứa và trạng thái giao dịch nâng cấp.
##
## Mỗi cấp thêm năm chỗ. Người gọi điều phối giao dịch bằng begin_purchase,
## commit và end_purchase, đồng thời chịu trách nhiệm thông báo thay đổi.

## Signal dành cho nơi điều phối phát khi cấp chuồng thay đổi.
signal changed(pen_id: StringName)
## Danh mục xác định các mã chuồng được hỗ trợ.
const CATALOG: PenUpgradeCatalog = preload("res://resources/animals/pen_upgrades.tres")
## Cấp chuồng tối đa.
const MAX_LEVEL: int = 6
## Số chỗ vật nuôi cho mỗi cấp.
const SLOTS_PER_LEVEL: int = 5
var _levels: Dictionary = fresh()
var _busy: bool = false

## Tạo dữ liệu mới với mọi chuồng trong danh mục ở cấp 1.
static func fresh() -> Dictionary:
	var result: Dictionary = {}
	for id: String in CATALOG.pen_kinds:
		result[id] = 1
	return result

## Kiểm tra đủ mã chuồng và mỗi cấp là số nguyên từ 1 đến cấp tối đa.
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != CATALOG.pen_kinds.size():
		return false
	for id: String in CATALOG.pen_kinds:
		var value: Variant = data.get(id)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 1 or value > MAX_LEVEL or float(value) != floor(float(value)):
			return false
	return true

## Tạo cấp chuồng từ số vật nuôi trong dữ liệu cũ, làm tròn lên theo sức chứa.
## Trả dictionary rỗng nếu dữ liệu vật nuôi sai cấu trúc.
static func migrate(animals: Variant) -> Dictionary:
	if not animals is Array:
		return {}
	var result: Dictionary = fresh()
	var populations: Dictionary = {}
	for row: Variant in animals:
		if not row is Dictionary or not row.get("pen") is String:
			return {}
		var id: String = row.pen
		populations[id] = int(populations.get(id, 0)) + 1
	for id: String in result:
		result[id] = clampi(ceili(float(populations.get(id, 0)) / SLOTS_PER_LEVEL), 1, MAX_LEVEL)
	return result

## Trả về cấp của chuồng, hoặc 0 khi mã không có trong trạng thái.
func level(id: StringName) -> int:
	return int(_levels.get(String(id), 0))

## Tính sức chứa từ cấp chuồng và số chỗ mỗi cấp.
func capacity(id: StringName) -> int:
	return level(id) * SLOTS_PER_LEVEL

## Tạo bản sao sâu của bảng cấp để lưu.
func capture() -> Dictionary:
	return _levels.duplicate(true)

## Thay bảng cấp bằng bản sao dữ liệu hợp lệ khi không có giao dịch đang chạy.
func restore(data: Dictionary) -> bool:
	if _busy or not valid(data):
		return false
	_levels = data.duplicate(true)
	return true

## Cho biết đang có giao dịch mua nâng cấp.
func is_busy() -> bool:
	return _busy

## Đánh dấu bắt đầu giao dịch nếu chưa có giao dịch khác.
func begin_purchase() -> bool:
	if _busy:
		return false
	_busy = true
	return true

## Tăng cấp một bậc nếu giao dịch đang mở và cấp hiện tại khớp giá trị dự kiến.
## Trả về false nếu điều kiện không đạt hoặc đã ở cấp tối đa.
func commit(id: StringName, expected_level: int) -> bool:
	if not _busy or level(id) != expected_level or expected_level < 1 or expected_level >= MAX_LEVEL:
		return false
	_levels[String(id)] = expected_level + 1
	return true

## Kết thúc trạng thái giao dịch sau khi người gọi hoàn tất xử lý.
func end_purchase() -> void:
	_busy = false
