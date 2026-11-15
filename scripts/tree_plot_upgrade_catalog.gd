class_name TreePlotUpgradeCatalog
extends Resource
## Bảng giá nâng cấp ô trồng cây ăn quả và cây lấy gỗ.

## Ánh xạ mã loại cây sang mảng 16 mức giá tăng dần.
@export var prices: Dictionary = {}

## Kiểm tra đủ hai nhóm, mỗi nhóm có 16 giá nguyên hữu hạn tăng nghiêm ngặt.
func valid() -> bool:
	if prices.size() != 2:
		return false
	for id: String in ["fruit", "timber"]:
		var rows: Variant = prices.get(id)
		if not rows is Array or rows.size() != 16:
			return false
		var previous: int = 0
		for value: Variant in rows:
			if not (value is int or value is float) or not is_finite(float(value)) or value <= previous or value != floor(float(value)):
				return false
			previous = int(value)
	return true

## Trả về giá tại cấp được yêu cầu, hoặc 0 nếu cấp ngoài mảng giá.
func price(kind: TreeDefinition.Kind, level: int) -> int:
	var rows: Array = prices.get("fruit" if kind == TreeDefinition.Kind.FRUIT else "timber", [])
	return int(rows[level - 1]) if level >= 1 and level <= rows.size() else 0
