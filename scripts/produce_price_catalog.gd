class_name ProducePriceCatalog
extends Resource
## Danh mục giá bán nông sản, tra cứu theo mã vật phẩm.

## Các mức giá được cấu hình cho danh mục.
@export var entries: Array[ProducePrice] = []

## Yêu cầu danh mục có ít nhất một mục hợp lệ và không lặp mã vật phẩm.
func is_valid() -> bool:
	var seen: Dictionary = {}
	for entry: ProducePrice in entries:
		if entry == null or not entry.is_valid() or seen.has(entry.item.item_id):
			return false
		seen[entry.item.item_id] = true
	return not entries.is_empty()

## Tìm mục giá hợp lệ đầu tiên có mã [param item_id], hoặc trả về null.
func find(item_id: StringName) -> ProducePrice:
	for entry: ProducePrice in entries:
		if entry != null and entry.is_valid() and entry.item.item_id == item_id:
			return entry
	return null
