class_name ObjectiveProgress
extends RefCounted
## Tiến độ mục tiêu tuần tự và nhận thưởng xu, độc lập scene và giao diện.
## Chỉ mục tiêu chưa nhận thưởng đầu tiên được ghi tiến độ.

## Phát khi tiến độ hoặc lựa chọn hiển thị thay đổi.
signal changed
## Phát sau khi khôi phục trạng thái nếu không đang tạm ngưng thông báo.
signal restored
## Catalog mục tiêu hướng dẫn mặc định.
const DEFAULT_CATALOG: ObjectiveCatalog = preload("res://resources/objectives/onboarding.tres")
## Danh sách định nghĩa mục tiêu.
var catalog: ObjectiveCatalog
## Ví nhận thưởng.
var wallet: WalletComponent
## Hàm truy vấn trạng thái thế giới cho mục tiêu dựa trên trạng thái.
var state_query: Callable
## Tạm ngưng xử lý và thông báo trong quá trình khôi phục.
var suspended: bool = false
## Mã mục tiêu được ghim trên HUD.
var tracked_id: String = ""
## Trạng thái thu gọn HUD.
var hud_collapsed: bool = false
var _rows: Array = []
var _busy: bool = false

func _init(purse: WalletComponent, query: Callable = Callable(), definitions: ObjectiveCatalog = DEFAULT_CATALOG) -> void:
	assert(definitions != null and definitions.is_valid(), "Invalid objective catalog")
	wallet = purse
	state_query = query
	catalog = definitions
	_rows = ObjectiveSaveSchema.fresh(catalog).steps

## Chỉ số mục tiêu đầu tiên chưa nhận thưởng, hoặc -1 nếu đã nhận hết.
func active_index() -> int:
	for index: int in range(_rows.size()):
		if not _rows[index].claimed:
			return index
	return -1

## Định nghĩa mục tiêu hiện hành, hoặc null nếu đã hoàn tất.
func active() -> ObjectiveDefinition:
	var index: int = active_index()
	return catalog.steps[index] if index >= 0 else null

## Tiến độ mục tiêu hiện hành, hoặc 0 nếu không còn mục tiêu.
func progress() -> int:
	var index: int = active_index()
	return int(_rows[index].progress) if index >= 0 else 0

## Kiểm tra mục tiêu hiện hành đã đạt đủ tiến độ.
func ready_to_claim() -> bool:
	var step: ObjectiveDefinition = active()
	return step != null and progress() == step.required

## Ghi sự kiện dương phù hợp điều kiện mục tiêu hiện hành, không vượt mức yêu cầu.
## Mục tiêu dựa trên trạng thái được cập nhật qua [method refresh_state].
func record(condition: StringName, amount: int = 1) -> void:
	var step: ObjectiveDefinition = active()
	if suspended or _busy or step == null or step.state_condition or step.condition != condition or amount <= 0 or ready_to_claim():
		return
	_rows[active_index()].progress = progress() + mini(amount, step.required - progress())
	changed.emit()

func _refresh_active() -> bool:
	var step: ObjectiveDefinition = active()
	if step == null or not step.state_condition or not state_query.is_valid():
		return false
	var value: int = clampi(int(state_query.call(step.condition)), 0, step.required)
	if value <= progress():
		return false
	_rows[active_index()].progress = value
	return true

## Truy vấn trạng thái và tăng tiến độ mục tiêu hiện hành nếu giá trị cao hơn.
func refresh_state() -> void:
	if not suspended and not _busy and _refresh_active():
		changed.emit()

## Nhận thưởng của mục tiêu hiện hành đã hoàn tất nếu ví còn chỗ.
## Cập nhật ví và cờ nhận thưởng trước khi phát signal, rồi làm mới mục kế tiếp.
func claim(id: StringName) -> Dictionary:
	var step: ObjectiveDefinition = active()
	if suspended or _busy or step == null or step.objective_id != id or not ready_to_claim():
		return {"ok": false, "error": "This objective is not ready to claim."}
	if not is_instance_valid(wallet) or step.reward_coins > WalletComponent.MAX_COINS - wallet.balance:
		return {"ok": false, "error": "Your wallet has reached its coin limit."}
	_busy = true
	# Observers/saves must see the credited wallet and claimed flag together.
	wallet.set_balance(wallet.balance + step.reward_coins, false)
	_rows[active_index()].claimed = true
	if tracked_id == String(id):
		tracked_id = ""
	_refresh_active()
	wallet.changed.emit(wallet.balance)
	changed.emit()
	_busy = false
	return {"ok": true, "coins": step.reward_coins}

## Tạo bản sao tiến độ, mục tiêu ghim và trạng thái HUD để lưu.
func capture() -> Dictionary:
	return {"steps": _rows.duplicate(true), "tracked_id": tracked_id, "hud_collapsed": hud_collapsed}

## Ghim mục tiêu có mã trong catalog và phát changed.
func track(id: String) -> void:
	if suspended or _busy:
		return
	for definition: ObjectiveDefinition in catalog.steps:
		if String(definition.objective_id) == id:
			tracked_id = id
			changed.emit()
			return

## Đổi trạng thái thu gọn HUD và phát changed khi giá trị đổi.
func set_collapsed(value: bool) -> void:
	if suspended or _busy or hud_collapsed == value:
		return
	hud_collapsed = value
	changed.emit()

## Trả chỉ số mục tiêu được ghim, nếu không có thì dùng mục tiêu hiện hành.
func tracked_index() -> int:
	for index: int in range(catalog.steps.size()):
		if String(catalog.steps[index].objective_id) == tracked_id:
			return index
	return active_index()

## Kiểm tra và khôi phục dữ liệu, làm mới mục tiêu trạng thái và phát signal.
func restore(data: Dictionary) -> bool:
	if _busy or not ObjectiveSaveSchema.valid(data, catalog):
		return false
	_rows = data.steps.duplicate(true)
	tracked_id = data.tracked_id
	hud_collapsed = data.hud_collapsed
	for row: Dictionary in _rows:
		row.progress = int(row.progress)
	_refresh_active()
	if not suspended:
		restored.emit()
		changed.emit()
	return true
