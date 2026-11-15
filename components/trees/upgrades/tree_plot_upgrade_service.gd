class_name TreePlotUpgradeService
extends RefCounted
## Báo giá và mua mở rộng khu trồng cây ăn quả hoặc cây lấy gỗ.
## Tiền và cấp được cập nhật trước khi phát signal; tiền được hoàn lại nếu
## không thể ghi cấp sau khi trừ tiền.

## Phát sau khi mua thành công để yêu cầu lưu.
signal save_requested
## Thế giới chứa các hệ thống có thể đang giao dịch.
var world: FarmWorld
## Ví dùng để thanh toán.
var wallet: WalletComponent
## Trạng thái cấp và khóa giao dịch.
var state: TreePlotUpgradeState = TreePlotUpgradeState.new()
## Danh mục giá nâng cấp.
var catalog: TreePlotUpgradeCatalog = TreePlotUpgradeState.CATALOG
## Cho biết profile đã sẵn sàng.
var profile_ready: bool = false

func _init(farm: FarmWorld) -> void:
	world = farm
	wallet = world.player.wallet

## Khôi phục trạng thái hợp lệ và thông báo thay đổi cho cả hai loại khu.
func restore(data: Dictionary) -> bool:
	if not state.restore(data):
		return false
	state.changed.emit(TreeDefinition.Kind.FRUIT)
	state.changed.emit(TreeDefinition.Kind.TIMBER)
	return true

func _failure(code: String, message: String, offer: Dictionary = {}) -> Dictionary:
	return offer.merged({"ok":false, "code":code, "error":message}, true)

## Báo cấp, sức chứa hiện tại, sức chứa tiếp theo và giá.
## Kết quả lỗi có mã và thông báo khi dữ liệu không sẵn sàng, đạt cấp tối đa,
## hệ thống đang bận hoặc số dư không đủ.
func quote(kind: TreeDefinition.Kind) -> Dictionary:
	if not catalog.valid() or kind not in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER] or not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(wallet):
		return _failure("unavailable", "Tree plot upgrades are unavailable.")
	var current: int = state.level(kind)
	var offer: Dictionary = {"ok":true, "kind":kind, "level":current, "capacity":state.capacity(kind), "next_capacity":(current + 1) * 9, "price":catalog.price(kind, current)}
	if current >= TreePlotUpgradeState.MAX_LEVEL:
		return _failure("max_level", "Maximum capacity reached: 153 tree plots.", offer)
	if state.is_busy() or (world.pen_upgrades != null and world.pen_upgrades.state.is_busy()) or (world.trees != null and world.trees.is_busy()) or (world.tool_upgrade_state != null and world.tool_upgrade_state.is_busy()) or (world.storages != null and world.storages.busy) or world.wood_market.busy or (world.workers != null and world.workers.busy):
		return _failure("busy", "A trade is in progress.", offer)
	if not profile_ready:
		return _failure("unavailable", "Tree plot upgrades are unavailable.", offer)
	if wallet.balance < int(offer.price):
		offer["missing"] = int(offer.price) - wallet.balance
		return _failure("insufficient_coins", "Not enough coins.", offer)
	return offer

## Kiểm tra lại báo giá, trừ xu và tăng cấp nếu cấp và giá dự kiến còn khớp.
## Phát thay đổi ví, cấp và yêu cầu lưu sau khi giao dịch thành công.
func purchase(kind: TreeDefinition.Kind, expected_level: int, expected_price: int) -> Dictionary:
	var offer: Dictionary = quote(kind)
	if not offer.ok:
		return offer
	if offer.level != expected_level or offer.price != expected_price:
		return _failure("stale_offer", "The tree plot upgrade offer changed. Please try again.")
	if not state.begin_purchase():
		return _failure("busy", "A trade is in progress.")
	var balance: int = wallet.balance
	if not wallet.set_balance(balance - int(offer.price), false):
		state.end_purchase()
		return _failure("unavailable", "Unable to spend coins.")
	if not state.commit(kind, expected_level):
		wallet.set_balance(balance, false)
		state.end_purchase()
		return _failure("stale_offer", "The tree plot upgrade offer changed. Please try again.")
	wallet.changed.emit(wallet.balance)
	state.changed.emit(kind)
	state.end_purchase()
	save_requested.emit()
	return {"ok":true, "capacity":state.capacity(kind), "price":offer.price}
