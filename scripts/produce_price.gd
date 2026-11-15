class_name ProducePrice
extends Resource
## Giá bán của một loại nông sản, cấu hình bằng resource trong editor.

## Định nghĩa vật phẩm phải thuộc loại nông sản và có mã không rỗng.
@export var item: ItemDefinition
## Giá bán cho một đơn vị, tính bằng xu.
@export_range(1, 1000000) var price: int = 1

## Kiểm tra vật phẩm, loại và mã cùng phạm vi giá từ 1 đến 1.000.000 xu.
func is_valid() -> bool:
	return item != null and not item.item_id.is_empty() and item.item_type == ItemDefinition.ItemType.PRODUCE and price >= 1 and price <= 1000000
