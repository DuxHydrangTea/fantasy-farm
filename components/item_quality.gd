class_name ItemQuality
extends RefCounted
## Quy tắc chất lượng vật phẩm, thứ tự chọn cấp và cách hiển thị, định giá.
## Mỗi chồng thông thường có một cấp; định nghĩa vật phẩm vẫn được dùng chung.

## Ba cấp chất lượng theo thứ tự tăng dần.
enum Tier { NORMAL, SILVER, GOLD }

## Tạo chế độ chỉ chấp nhận đúng một cấp chất lượng.
static func exact(tier: int = 0) -> Dictionary:
	return {"allowed": [tier], "high_first": false}

## Tạo chế độ chấp nhận tập cấp đã cho, với thứ tự ưu tiên tùy chọn.
static func tier_set(allowed: Array, high_first: bool = false) -> Dictionary:
	return {"allowed": allowed.duplicate(), "high_first": high_first}

## Kiểm tra chế độ và trả các cấp theo thứ tự ưu tiên, hoặc mảng rỗng nếu sai.
static func order(mode: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if not mode.get("allowed") is Array or not mode.get("high_first") is bool:
		return result
	for tier: Variant in mode.allowed:
		if not tier is int or tier < 0 or tier > 2 or result.has(tier):
			return []
		result.append(tier)
	result.sort()
	if mode.high_first:
		result.reverse()
	return result

## Kiểm tra cấp nằm trong 0–2 và vật phẩm hỗ trợ cấp đó.
## Cấp cao chỉ dành cho nông sản không phải biến thể star_fruit.
static func supported(item: ItemDefinition, tier: int) -> bool:
	return tier >= 0 and tier < 3 and (tier == 0 or (item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit))

## Kiểm tra ba số lượng nguyên không âm, cấp được hỗ trợ và tổng bằng amount.
static func valid_tiers(value: Variant, item: ItemDefinition, amount: int) -> bool:
	if not value is Array or value.size() != 3:
		return false
	var total: int = 0
	for tier: int in range(3):
		var count: Variant = value[tier]
		if not (count is int or count is float) or not is_finite(float(count)) or float(count) != floorf(float(count)) or count < 0 or count > 32000 or (count > 0 and not supported(item, tier)):
			return false
		total += int(count)
	return total == amount

## Tên chất lượng đã dịch; cấp ngoài phạm vi được kẹp vào 0–2.
static func label(tier: int) -> String:
	return TranslationServer.translate(["Normal", "Silver", "Gold"][clampi(tier, 0, 2)])

## Định dạng số lượng ở cả ba cấp thành một dòng.
static func summary(tiers: Array) -> String:
	return "%s: %d · %s: %d · %s: %d" % [label(0), tiers[0], label(1), tiers[1], label(2), tiers[2]]

## Màu hiển thị cho cấp chất lượng.
static func color(tier: int) -> Color:
	return [Color.WHITE, Color(0.72, 0.85, 1.0), Color(1.0, 0.78, 0.22)][clampi(tier, 0, 2)]

## Giá một đơn vị sau hệ số 1, 1,8 hoặc 3,5 và làm tròn.
static func unit_price(price: int, tier: int) -> int:
	return roundi(price * [1.0, 1.8, 3.5][clampi(tier, 0, 2)])

## Cấp đầu tiên có số lượng dương, hoặc 0 nếu chồng rỗng.
static func stack_tier(tiers: Array) -> int:
	for tier: int in range(3):
		if int(tiers[tier]) > 0:
			return tier
	return 0

## Kiểm tra mảng có tối đa một cấp có số lượng dương.
static func homogeneous(tiers: Array) -> bool:
	var kinds: int = 0
	for value: Variant in tiers:
		if int(value) > 0:
			kinds += 1
	return kinds <= 1

## Tên vật phẩm đã dịch, thêm nhãn chất lượng cho nông sản phù hợp.
static func item_name(item: ItemDefinition, tiers: Array) -> String:
	if item == null:
		return TranslationServer.translate("Empty slot")
	var name: String = TranslationServer.translate(item.display_name)
	if item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit:
		name += " · " + label(stack_tier(tiers))
	return name
