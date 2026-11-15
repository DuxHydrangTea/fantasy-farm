class_name AnimalProductionComponent
extends Node
## Theo dõi tiến độ và lượng sản phẩm chờ thu của một vật nuôi.
## Actor cung cấp thời gian đủ điều kiện và quyết định cách chuyển sản phẩm.

## Phát số lượng sản phẩm vừa hoàn thành.
signal produced(amount: int)
## Phát tổng lượng sản phẩm đang chờ thu sau khi thay đổi.
signal stock_changed(amount: int)
## Cấu hình loại sản phẩm và chu kỳ sản xuất.
var definition: AnimalProductionDefinition
## Phần thời gian đã tích lũy trong chu kỳ hiện tại, tính bằng giây.
var progress_seconds: float = 0.0
## Lượng sản phẩm đã hoàn thành và chưa lấy đi.
var stored_amount: int = 0
## Cho biết thuốc tăng sản phẩm đang chờ chu kỳ hoàn thành tiếp theo.
var tonic_pending: bool = false
## Hàm trả số ngẫu nhiên dùng để quyết định thưởng thuốc, có thể thay khi kiểm thử.
var bonus_roll: Callable = func() -> float: return randf()
var _collecting: bool = false

## Gắn cấu hình mới và đặt lại tiến độ, sản phẩm tồn và trạng thái thuốc.
func configure(data: AnimalProductionDefinition) -> void:
	tonic_pending = false
	definition = data
	progress_seconds = 0.0
	stored_amount = 0

## Tỉ lệ tiến độ trên thời gian chu kỳ, hoặc 0 nếu cấu hình không hợp lệ.
func progress_ratio() -> float:
	return progress_seconds / definition.production_seconds if definition != null and definition.is_valid() else 0.0

## Khôi phục tiến độ, lượng tồn và thuốc chờ từ dữ liệu đã kiểm tra.
## Phát [signal stock_changed] sau khi khôi phục.
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
## Cộng thời gian đủ điều kiện, hoàn thành các chu kỳ và giữ phần thời gian dư.
## Trả về số sản phẩm mới, đồng thời cộng vào tồn và phát signal tương ứng.
## Thuốc chờ chỉ áp dụng cho chu kỳ đầu tiên, với 50% cơ hội thêm một sản phẩm.
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

## Lấy tối đa [param amount] sản phẩm đang tồn và trả về số thực lấy.
## Khi [param notify] bật, phát thay đổi tồn nếu có sản phẩm được lấy.
func take_output(amount: int, notify: bool = true) -> int:
	var removed: int = mini(maxi(0, amount), stored_amount)
	if removed > 0:
		stored_amount -= removed
		if notify:
			stock_changed.emit(stored_amount)
	return removed

## Chuyển sản phẩm vào inventory và trả về số lượng inventory nhận được.
## Phần không vừa vẫn ở lại. Khóa gọi lồng nhau tránh thu trùng khi inventory
## phát signal trong lúc chuyển.
# inventory.add có thể nhận ít hơn yêu cầu nếu túi gần đầy; chỉ trừ kho đúng số thực nhận.
# _collecting chặn gọi lồng nhau: add phát changed ngay và listener có thể lại yêu cầu collect
# trước khi take_output kịp trừ kho. Không khóa thì một sản phẩm có thể được nhận hai lần.
## Chuyển sản phẩm đang lưu vào kho và trả số lượng được nhận.
func collect(inventory: InventoryComponent) -> int:
	if _collecting or inventory == null or definition == null or not definition.is_valid() or stored_amount <= 0:
		return 0
	_collecting = true
	var accepted: int = inventory.add(definition.production_item, stored_amount)
	take_output(accepted)
	_collecting = false
	return accepted

## Đặt thuốc cho chu kỳ hoàn thành tiếp theo nếu chưa có thuốc chờ và cấu hình hợp lệ.
## Trả về true khi áp dụng thành công.
func apply_tonic() -> bool:
	if tonic_pending or definition == null or not definition.is_valid():
		return false
	tonic_pending = true
	return true
