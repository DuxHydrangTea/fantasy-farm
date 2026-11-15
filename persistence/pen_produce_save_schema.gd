extends RefCounted
## Kiểm tra dữ liệu lưu kho sản phẩm chuồng trước khi khôi phục.
## Dữ liệu chỉ chứa mã vật phẩm và số lượng. Resource thực được tra từ catalog.

## Sức chứa tối đa dùng để kiểm tra tổng sản phẩm mỗi chuồng.
const CAPACITY: int = preload("res://components/animals/pen_produce_storage.gd").DEFAULT_CAPACITY

## Kiểm tra danh sách chuồng, mã sản phẩm, số lượng và sức chứa.
## Không chấp nhận mã chuồng hoặc mã sản phẩm trùng trong cùng phạm vi,
## sản phẩm ngoài catalog, số lượng không nguyên hoặc tổng vượt sức chứa.
static func valid(rows: Variant, catalog: SaveCatalog, pen_ids: Array) -> bool:
	if not rows is Array or rows.size() > 256:
		return false
	var seen: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary or not row.get("pen") is String or not row.pen in pen_ids or seen.has(row.pen) or not row.get("products") is Array or row.products.size() > 100:
			return false
		seen[row.pen] = true
		var items: Dictionary = {}
		var total: int = 0
		for stack: Variant in row.products:
			if not stack is Dictionary or not stack.get("item") is String or not catalog.items.has(stack.item) or items.has(stack.item) or not _amount(stack.get("amount")):
				return false
			items[stack.item] = true
			total += int(stack.amount)
		if total > CAPACITY:
			return false
	return true

static func _amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 1 and float(value) <= CAPACITY and float(value) == floor(float(value))
