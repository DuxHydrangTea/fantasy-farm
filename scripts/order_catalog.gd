class_name OrderCatalog
extends Resource
## Danh mục đơn hiện hành và liên kết đến danh mục đơn cũ.

## Các đơn hiện có trong danh mục.
@export var entries: Array[OrderDefinition] = []
## Danh mục cũ giúp hoàn thành đơn đã phát hành theo số lượng và thưởng gốc.
@export var legacy_catalog: Resource

## Tìm đơn theo mã, tìm tiếp trong danh mục cũ khi không có ở danh mục này.
## Trả về null khi không tìm thấy.
func find(id: StringName) -> OrderDefinition:
	for entry: OrderDefinition in entries:
		if entry != null and entry.order_id == id:
			return entry
	return (legacy_catalog as OrderCatalog).find(id) if legacy_catalog is OrderCatalog else null

## Kiểm tra danh mục hiện hành không rỗng, các đơn hợp lệ và mã không trùng.
func is_valid() -> bool:
	var seen: Dictionary = {}
	for entry: OrderDefinition in entries:
		if entry == null or not entry.is_valid() or seen.has(entry.order_id):
			return false
		seen[entry.order_id] = true
	return not entries.is_empty()
