class_name TutorialProgress
extends RefCounted
## Lưu tùy chọn hiển thị hướng dẫn và việc đã dùng hỗ trợ khởi đầu.
## Tiến độ hoàn thành nhiệm vụ gameplay thuộc ObjectiveProgress.

## Phát khi dữ liệu hướng dẫn thay đổi.
signal changed
var _data: Dictionary = TutorialSaveSchema.fresh()
var _busy: bool = false

## Tạo bản sao sâu dữ liệu để lưu.
func capture() -> Dictionary:
	return _data.duplicate(true)

## Kiểm tra và khôi phục dữ liệu khi không có thao tác đang chạy.
func restore(data: Dictionary) -> bool:
	if _busy or not TutorialSaveSchema.valid(data):
		return false
	_busy = true
	_data = data.duplicate(true)
	changed.emit()
	_busy = false
	return true

## Bật hoặc tắt hướng dẫn; khi bật, xóa cờ đã bỏ qua.
func set_enabled(value: bool) -> void:
	if _busy:
		return
	_data.enabled = value
	if value:
		_data.skipped = false
	changed.emit()

## Tắt và đánh dấu hướng dẫn đã bị bỏ qua.
func skip() -> void:
	if _busy:
		return
	_data.enabled = false
	_data.skipped = true
	changed.emit()

## Kiểm tra người chơi đã xem hướng dẫn có mã này.
func seen(id: String) -> bool:
	return _data.seen.has(id)

## Ghi mã hướng dẫn hợp lệ chưa được xem và phát changed.
func mark_seen(id: String) -> void:
	if _busy or seen(id) or not TutorialSaveSchema.known(id):
		return
	_data.seen.append(id)
	changed.emit()

## Cấp một hạt giống hỗ trợ tối đa một lần nếu túi còn chỗ.
## Hoàn tác cờ đã dùng nếu túi không nhận đủ vật phẩm.
func grant_support(bag: InventoryComponent, seed_item: ItemDefinition) -> bool:
	if _busy or _data.support_used or bag.capacity_for(seed_item) < 1:
		return false
	_busy = true
	_data.support_used = true
	var accepted: int = bag.add(seed_item, 1)
	if accepted != 1:
		_data.support_used = false
	changed.emit()
	_busy = false
	return accepted == 1
