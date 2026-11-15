class_name OrderDefinition
extends Resource
## Cấu hình một đơn đặt nông sản với mã ổn định dùng trong dữ liệu lưu.
##
## Các mảng [member items] và [member amounts] tương ứng theo chỉ số.
## Dữ liệu lưu giữ mã đơn, còn tên, nội dung và phần thưởng lấy từ resource.

## Mã nhận diện đơn ổn định.
@export var order_id: StringName
## Tên hiển thị của đơn.
@export var title: String
## Một hoặc hai loại nông sản cần giao.
@export var items: Array[ItemDefinition] = []
## Số lượng yêu cầu tương ứng với từng mục trong [member items].
@export var amounts: Array[int] = []
## Phần thưởng bằng xu khi hoàn thành.
@export var reward_coins: int = 1

## Kiểm tra mã, tên, phần thưởng và các dòng nông sản hợp lệ.
## Mỗi mã vật phẩm chỉ xuất hiện một lần, số lượng nằm trong khoảng 1–32.000.
func is_valid() -> bool:
	if order_id.is_empty() or title.is_empty() or items.is_empty() or items.size() > 2 or amounts.size() != items.size() or reward_coins <= 0:
		return false
	var seen: Dictionary = {}
	for index: int in range(items.size()):
		var item: ItemDefinition = items[index]
		if item == null or item.item_type != ItemDefinition.ItemType.PRODUCE or item.item_id.is_empty() or seen.has(item.item_id) or amounts[index] < 1 or amounts[index] > 32000:
			return false
		seen[item.item_id] = true
	return true
