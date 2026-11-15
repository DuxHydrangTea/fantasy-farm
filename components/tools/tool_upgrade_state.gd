class_name ToolUpgradeState
extends RefCounted
## Cấp và kích thước vùng đang chọn của công cụ người chơi trong profile.
## Trạng thái này độc lập với vật phẩm trong túi và nâng cấp công nhân.

## Phát mã công cụ khi lựa chọn hoặc cấp thay đổi.
signal changed(tool: StringName)
## Các công cụ có thể nâng cấp vùng.
const TOOLS: Array[StringName] = [&"hoe", &"watering_can", &"sowing"]
## Cấp tối đa của mỗi công cụ.
const MAX_LEVEL: int = 6
var _progress: Dictionary = fresh()
var _busy: bool = false

## Tạo cấp và kích thước ban đầu bằng 1 cho mọi công cụ.
static func fresh() -> Dictionary:
	return {"hoe": {"level": 1, "selected_size": 1}, "watering_can": {"level": 1, "selected_size": 1}, "sowing": {"level": 1, "selected_size": 1}}

## Kiểm tra đủ công cụ, cấp hợp lệ và kích thước đã chọn không vượt cấp.
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != TOOLS.size():
		return false
	for tool: StringName in TOOLS:
		var row: Variant = data.get(String(tool))
		if not row is Dictionary or row.size() != 2 or not _integer(row.get("level"), 1, MAX_LEVEL):
			return false
		if not _integer(row.get("selected_size"), 1, int(row.level)):
			return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and float(value) == floor(float(value))

## Lấy cấp công cụ, hoặc 0 với mã không được hỗ trợ.
func level(tool: StringName) -> int:
	return int(_progress[String(tool)].level) if tool in TOOLS else 0

## Lấy kích thước vùng đang chọn, hoặc 0 với mã không được hỗ trợ.
func selected_size(tool: StringName) -> int:
	return int(_progress[String(tool)].selected_size) if tool in TOOLS else 0

## Chọn kích thước từ 1 đến cấp hiện tại khi không có giao dịch mua.
## Phát changed nếu lựa chọn thực sự đổi.
func select_size(tool: StringName, size: int) -> bool:
	if _busy or not tool in TOOLS or size < 1 or size > level(tool):
		return false
	if selected_size(tool) != size:
		_progress[String(tool)].selected_size = size
		changed.emit(tool)
	return true

## Tạo bản sao sâu của tiến độ để lưu.
func capture() -> Dictionary:
	return _progress.duplicate(true)

## Khôi phục dữ liệu hợp lệ khi không đang mua, tùy chọn thông báo từng công cụ.
func restore(data: Dictionary, notify: bool = true) -> bool:
	if _busy or not valid(data):
		return false
	var next: Dictionary = {}
	for tool: StringName in TOOLS:
		var row: Dictionary = data[String(tool)]
		next[String(tool)] = {"level": int(row.level), "selected_size": int(row.selected_size)}
	_progress = next
	if notify:
		notify_restored()
	return true

## Phát changed cho từng công cụ sau khi khôi phục.
func notify_restored() -> void:
	for tool: StringName in TOOLS:
		changed.emit(tool)

## Cho biết giao dịch nâng cấp đang được xử lý.
func is_busy() -> bool:
	return _busy

## Khóa trạng thái để bắt đầu mua nếu chưa có giao dịch.
func begin_purchase() -> bool:
	if _busy:
		return false
	_busy = true
	return true

## Tăng cấp và chọn kích thước mới nếu khóa đang giữ và cấp dự kiến còn khớp.
func commit_upgrade(tool: StringName, expected_level: int) -> bool:
	if not _busy or not tool in TOOLS or level(tool) != expected_level or expected_level >= MAX_LEVEL:
		return false
	_progress[String(tool)] = {"level": expected_level + 1, "selected_size": expected_level + 1}
	return true

## Kết thúc khóa giao dịch.
func end_purchase() -> void:
	_busy = false
