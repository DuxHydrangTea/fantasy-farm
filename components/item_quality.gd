class_name ItemQuality
extends RefCounted
## Quality belongs to quantities, never to shared ItemDefinition resources.
enum Tier { NORMAL, SILVER, GOLD }

static func exact(tier: int = 0) -> Dictionary:
	return {"allowed": [tier], "high_first": false}

static func tier_set(allowed: Array, high_first: bool = false) -> Dictionary:
	return {"allowed": allowed.duplicate(), "high_first": high_first}

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

static func supported(item: ItemDefinition, tier: int) -> bool:
	return tier >= 0 and tier < 3 and (tier == 0 or (item != null and item.item_type == ItemDefinition.ItemType.PRODUCE))

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

static func label(tier: int) -> String:
	return TranslationServer.translate(["Normal", "Silver", "Gold"][clampi(tier, 0, 2)])

static func summary(tiers: Array) -> String:
	return "%s: %d · %s: %d · %s: %d" % [label(0), tiers[0], label(1), tiers[1], label(2), tiers[2]]

static func color(tier: int) -> Color:
	return [Color.WHITE, Color(0.72, 0.85, 1.0), Color(1.0, 0.78, 0.22)][clampi(tier, 0, 2)]

static func unit_price(price: int, tier: int) -> int:
	return roundi(price * [1.0, 1.8, 3.5][clampi(tier, 0, 2)])
