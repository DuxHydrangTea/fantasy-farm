class_name AnimalProductionComponent
extends Node
## Pure production state. The actor hands eligible time in and delivers output.
signal produced(amount: int)
signal stock_changed(amount: int)
var definition: AnimalProductionDefinition
var progress_seconds: float = 0.0
var stored_amount: int = 0
var tonic_pending: bool = false
var bonus_roll: Callable = func() -> float: return randf()
var _collecting: bool = false

func configure(data: AnimalProductionDefinition) -> void:
	tonic_pending = false
	definition = data
	progress_seconds = 0.0
	stored_amount = 0

func progress_ratio() -> float:
	return progress_seconds / definition.production_seconds if definition != null and definition.is_valid() else 0.0

func restore_state(progress: float, amount: int, pending: bool = false) -> void:
	progress_seconds = progress
	tonic_pending = pending
	stored_amount = amount
	stock_changed.emit(stored_amount)

# Đếm lô thay vì vòng lặp từng sản phẩm: lô = floor(tổng giây đủ điều kiện / chu kỳ).
# Giữ lại phần dư để tick sau tiếp tục, ví dụ 125 giây / chu kỳ 60 -> 2 lô, còn 5 giây.
# Số 0.000001 chỉ bù sai số số thực ở ranh giới chu kỳ, không phải thời gian thưởng thêm đáng kể.
# Bỏ phần dư sẽ làm mất tiến độ; lặp từng giây/lô khi offline dài sẽ tốn thời gian không cần thiết.
# Điều kiện bắt buộc là bảo toàn sản phẩm + phần dư, không bắt buộc phải dùng đúng cách đếm này.
func advance(eligible_seconds: float) -> int:
	if eligible_seconds <= 0.0 or definition == null or not definition.is_valid():
		return 0
	progress_seconds += eligible_seconds
	var batches: int = floori((progress_seconds + 0.000001) / definition.production_seconds)
	if batches <= 0:
		return 0
	progress_seconds = maxf(0.0, progress_seconds - batches * definition.production_seconds)
	var amount: int = batches * definition.production_amount
	if tonic_pending:
		# Only the first completed cycle is enhanced, even after a long offline jump.
		# Consume before signals; output collection/stock does not control this effect.
		tonic_pending = false
		if float(bonus_roll.call()) < 0.5:
			amount += 1
	stored_amount += amount
	stock_changed.emit(stored_amount)
	produced.emit(amount)
	return amount

func take_output(amount: int) -> int:
	var removed: int = mini(maxi(0, amount), stored_amount)
	if removed > 0:
		stored_amount -= removed
		stock_changed.emit(stored_amount)
	return removed

## Used by DIRECT_COLLECTION definitions; partial transfers preserve the rest.
# inventory.add có thể nhận ít hơn yêu cầu nếu túi gần đầy; chỉ trừ kho đúng số thực nhận.
# _collecting chặn gọi lồng nhau: add phát changed ngay và listener có thể lại yêu cầu collect
# trước khi take_output kịp trừ kho. Không khóa thì một sản phẩm có thể được nhận hai lần.
func collect(inventory: InventoryComponent) -> int:
	if _collecting or inventory == null or definition == null or not definition.is_valid() or stored_amount <= 0:
		return 0
	_collecting = true
	var accepted: int = inventory.add(definition.production_item, stored_amount)
	take_output(accepted)
	_collecting = false
	return accepted

func apply_tonic() -> bool:
	if tonic_pending or definition == null or not definition.is_valid():
		return false
	tonic_pending = true
	return true
