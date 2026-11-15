class_name BeehiveProductionComponent
extends RefCounted
## Tích lũy công việc cho tối đa một mẻ mật đang làm hoặc đã sẵn sàng.
## Nguồn hoa được tính theo công việc đã đóng góp trong mẻ.

## Quy tắc tốc độ, ngưỡng đặc sản và sản phẩm.
var definition: BeehiveDefinition
## Công việc đã tích lũy trong mẻ, tính bằng giây cơ sở.
var work: float = 0.0
## Công việc đóng góp theo mã nguồn hoa.
var contributions: Dictionary = {}
## Vật phẩm hoàn thành đang chờ thu, hoặc null.
var ready_item: ItemDefinition
## Mẻ được chuyển từ dữ liệu cũ và dùng quy tắc cũ.
var legacy_batch: bool = false
## Mã công thức đã chốt khi bắt đầu mẻ trong chế độ vườn.
var batch_recipe: String = ""
## Sử dụng công thức bố trí hoa trong vườn.
var garden_mode: bool = false
## Tạm dừng khởi đầu mẻ mới nhưng cho phép mẻ đang làm tiếp tục.
var pause_new_batches: bool = false
var _collecting: bool = false

## Cộng thời gian sản xuất theo nguồn và hệ số, giới hạn tại một mẻ.
## Khi đủ công việc, xác định sản phẩm và dừng tích lũy đến khi được thu.
func advance(seconds: float, source: String, recipe: String = "mixed") -> void:
	if ready_item != null or seconds <= 0.0 or (pause_new_batches and work == 0.0):
		return
	if garden_mode and batch_recipe.is_empty():
		batch_recipe = recipe
	var rate: float = definition.honey_rate(source, legacy_batch)
	var earned: float = minf(seconds * rate,definition.cycle_seconds - work)
	work += earned
	if not garden_mode and not source.is_empty() and (legacy_batch or definition.is_specialty(source)):
		contributions[source] = float(contributions.get(source,0.0)) + earned
	if work >= definition.cycle_seconds - 0.000001:
		work = definition.cycle_seconds
		ready_item = expected_item()

## Chọn nguồn đóng góp nhiều nhất nếu đạt tỉ lệ đặc sản, hoặc chuỗi rỗng.
## Khi đóng góp bằng nhau, dùng mã nguồn theo thứ tự chữ.
func dominant_source() -> String:
	var best: String = ""
	var amount: float = 0.0
	for key: String in contributions:
		var value: float = float(contributions[key])
		if value > amount or (is_equal_approx(value,amount) and key < best):
			best = key
			amount = value
	return best if amount + 0.000001 >= definition.cycle_seconds * definition.specialty_ratio else ""

## Xác định vật phẩm của mẻ từ công thức vườn hoặc nguồn đóng góp chủ đạo.
func expected_item() -> ItemDefinition:
	return HoneyComboCatalog.item(batch_recipe) if garden_mode and not batch_recipe.is_empty() else definition.honey_for(dominant_source(), legacy_batch)

## Mẻ cũ cho một đơn vị; mẻ mới dùng số lượng trong cấu hình.
func batch_amount() -> int:
	return 1 if legacy_batch else definition.batch_amount

## Thu trọn mẻ vào túi nếu đủ chỗ, trả vật phẩm đã thu hoặc null.
## Trạng thái tổ được xóa trước khi inventory phát signal để tránh thu lặp.
func collect(bag: InventoryComponent) -> ItemDefinition:
	if _collecting or ready_item == null or bag == null:
		return null
	var amount: int = batch_amount()
	if bag.capacity_for(ready_item) < amount:
		bag.report_capacity_blocked(ready_item,amount)
		return null
	_collecting = true
	var item: ItemDefinition = ready_item
	# Bag listeners see both a received jar and an already emptied hive.
	ready_item = null
	work = 0.0
	contributions = {}
	legacy_batch = false
	batch_recipe = ""
	bag.add(item,amount)
	_collecting = false
	return item

## Chụp tiến độ, đóng góp, mã sản phẩm và cờ mẻ cũ để lưu.
func capture() -> Dictionary:
	return {"work":work,"contributions":contributions.duplicate(),"ready_item":String(ready_item.item_id) if ready_item != null else "", "legacy_batch": legacy_batch, "batch_recipe": batch_recipe}
