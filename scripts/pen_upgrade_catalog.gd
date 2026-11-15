class_name PenUpgradeCatalog
extends Resource
## Bảng giá nâng cấp riêng cho ba loại chuồng, tra cứu bằng mã chuồng ổn định.

## Ánh xạ mã chuồng sang loại coop, barn hoặc pond.
@export var pen_kinds: Dictionary = {}
## Ánh xạ loại chuồng sang năm giá cho các lần nâng cấp từ cấp 1 đến 6.
@export var prices: Dictionary = {}

## Kiểm tra đủ ba loại, mỗi loại có năm giá nguyên dương trong giới hạn ví,
## và mỗi mã chuồng hợp lệ ánh xạ đến một loại khác nhau.
func valid() -> bool:
	if pen_kinds.size() != 3 or prices.size() != 3:
		return false
	for kind: String in ["coop", "barn", "pond"]:
		var costs: Variant = prices.get(kind)
		if not costs is Array or costs.size() != 5:
			return false
		for cost: Variant in costs:
			if not (cost is int or cost is float) or not is_finite(float(cost)) or cost < 1 or cost > WalletComponent.MAX_COINS or float(cost) != floor(float(cost)):
				return false
	var kinds: Dictionary = {}
	for id: Variant in pen_kinds:
		if not id is String or id.is_empty() or not id.is_valid_identifier() or not pen_kinds[id] in ["coop", "barn", "pond"] or kinds.has(pen_kinds[id]):
			return false
		kinds[pen_kinds[id]] = true
	return true

## Trả về giá nâng cấp từ cấp hiện tại, hoặc 0 khi dữ liệu, mã hay cấp không hợp lệ.
func price(id: StringName, current_level: int) -> int:
	if not valid() or not pen_kinds.has(String(id)) or current_level < 1 or current_level >= 6:
		return 0
	return int(prices[pen_kinds[String(id)]][current_level - 1])
