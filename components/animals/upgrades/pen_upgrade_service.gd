class_name PenUpgradeService
extends RefCounted
## Điều phối báo giá và giao dịch nâng cấp sức chứa chuồng.
##
## Tiền, cấp và sức chứa được cập nhật trước khi phát signal để các bên
## quan sát thấy trạng thái nhất quán. Nếu không ghi được cấp, tiền được hoàn lại.

## Phát sau khi giao dịch thành công để yêu cầu lưu game.
signal save_requested
## Thế giới sở hữu các chuồng được quản lý.
var world: FarmWorld
## Ví dùng để thanh toán.
var wallet: WalletComponent
## Trạng thái cấp và khóa giao dịch.
var state: PenUpgradeState = PenUpgradeState.new()
## Bảng giá và ánh xạ mã chuồng.
var catalog: PenUpgradeCatalog = PenUpgradeState.CATALOG
## Cho biết profile đã sẵn sàng cho phép nâng cấp.
var profile_ready: bool = false

func _init(farm: FarmWorld) -> void:
	world = farm
	wallet = world.player.wallet
	apply_capacities()

## Kiểm tra chuồng còn hợp lệ, là con trực tiếp của thế giới và có mã trong catalog.
func managed(pen: AnimalPen) -> bool:
	return is_instance_valid(pen) and is_instance_valid(world) and pen.get_parent() == world and catalog.pen_kinds.has(String(pen.persistent_id))

## Áp dụng sức chứa từ trạng thái nâng cấp cho mọi chuồng được quản lý.
func apply_capacities() -> void:
	for node: Node in world.get_children():
		var pen: AnimalPen = node as AnimalPen
		if managed(pen):
			pen.capacity = state.capacity(pen.persistent_id)

## Khôi phục cấp chuồng hợp lệ và cập nhật sức chứa thực tế.
## Trả false nếu trạng thái từ chối dữ liệu hoặc đang có giao dịch.
func restore(data: Dictionary) -> bool:
	if not state.restore(data):
		return false
	apply_capacities()
	return true

func _failure(code: String, message: String, offer: Dictionary = {}) -> Dictionary:
	return offer.merged({"ok":false, "code":code, "error":message}, true)

## Báo cấp, sức chứa hiện tại, sức chứa kế tiếp và giá cho chuồng.
## Kết quả lỗi có [code]ok[/code] false, mã [code]code[/code] và [code]error[/code].
## Các điều kiện gồm catalog, profile, giới hạn cấp, giao dịch khác và số dư.
func quote(pen: AnimalPen) -> Dictionary:
	if not catalog.valid() or not managed(pen) or not pen.is_inside_tree() or pen.is_queued_for_deletion() or not is_instance_valid(wallet):
		return _failure("unavailable", "Pen upgrades are unavailable.")
	var current: int = state.level(pen.persistent_id)
	var offer: Dictionary = {"ok":true, "pen":String(pen.persistent_id), "level":current, "capacity":state.capacity(pen.persistent_id), "next_capacity":(current + 1) * 5, "price":catalog.price(pen.persistent_id, current)}
	if current >= PenUpgradeState.MAX_LEVEL:
		return _failure("max_level", "Maximum capacity reached: 30 animals.", offer)
	if state.is_busy() or (world.tree_plot_upgrades != null and world.tree_plot_upgrades.state.is_busy()) or (world.tool_upgrade_state != null and world.tool_upgrade_state.is_busy()) or (world.storages != null and world.storages.busy) or world.wood_market.busy or (world.workers != null and world.workers.busy):
		return _failure("busy", "A trade is in progress.", offer)
	if not profile_ready:
		return _failure("unavailable", "Pen upgrades are unavailable.", offer)
	if wallet.balance < int(offer.price):
		offer["missing"] = int(offer.price) - wallet.balance
		return _failure("insufficient_coins", "Not enough coins.", offer)
	return offer

## Mua nâng cấp sau khi kiểm tra lại báo giá và cấp, giá người gọi đã thấy.
## Khi thành công trả sức chứa và giá, phát thay đổi ví, cấp và yêu cầu lưu.
## Nếu cấp hoặc giá đã đổi, trả lỗi stale_offer để người gọi cập nhật báo giá.
func purchase(pen: AnimalPen, expected_level: int, expected_price: int) -> Dictionary:
	var offer: Dictionary = quote(pen)
	if not offer.ok:
		return offer
	if offer.level != expected_level or offer.price != expected_price:
		return _failure("stale_offer", "The pen upgrade offer changed. Please try again.")
	if not state.begin_purchase():
		return _failure("busy", "A trade is in progress.")
	var balance: int = wallet.balance
	if not wallet.set_balance(balance - int(offer.price), false):
		state.end_purchase()
		return _failure("unavailable", "Unable to spend coins.")
	if not state.commit(pen.persistent_id, expected_level):
		wallet.set_balance(balance, false)
		state.end_purchase()
		return _failure("stale_offer", "The pen upgrade offer changed. Please try again.")
	pen.capacity = state.capacity(pen.persistent_id)
	wallet.changed.emit(wallet.balance)
	state.changed.emit(pen.persistent_id)
	state.end_purchase()
	save_requested.emit()
	return {"ok":true, "capacity":pen.capacity, "price":offer.price}
