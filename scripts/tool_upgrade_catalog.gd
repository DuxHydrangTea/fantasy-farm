class_name ToolUpgradeCatalog
extends Resource
## Danh mục giá và điều kiện nâng cấp cho từng công cụ và cấp đích.

## Các lựa chọn mua nâng cấp.
@export var offers: Array[ToolUpgradeOffer] = []

## Kiểm tra đủ một lựa chọn cho mỗi cặp công cụ và cấp, không trùng cặp,
## cùng giới hạn hợp lệ của giá, gỗ và số cột đất đã mua.
func valid() -> bool:
	if offers.size() != ToolUpgradeState.TOOLS.size() * (ToolUpgradeState.MAX_LEVEL - 1):
		return false
	var seen: Dictionary = {}
	for offer: ToolUpgradeOffer in offers:
		if offer == null or not offer.tool in ToolUpgradeState.TOOLS or offer.target_level < 2 or offer.target_level > ToolUpgradeState.MAX_LEVEL:
			return false
		if offer.wood_cost < 0 or offer.wood_cost > WoodMarket.DAILY_CAP or offer.price < 1 or offer.price > WalletComponent.MAX_COINS or offer.required_purchased_columns < 0 or offer.required_purchased_columns >= LandExpansionState.REGION.size.x:
			return false
		var key: String = "%s:%d" % [offer.tool, offer.target_level]
		if seen.has(key):
			return false
		seen[key] = true
	return true

## Tìm lựa chọn theo mã công cụ và cấp đích, trả về null khi không tìm thấy.
func find(tool: StringName, target_level: int) -> ToolUpgradeOffer:
	for offer: ToolUpgradeOffer in offers:
		if offer != null and offer.tool == tool and offer.target_level == target_level:
			return offer
	return null
