class_name WorkerUpgradeService
extends RefCounted
## Báo giá và mua nâng cấp công nhân bằng xu.
##
## Trước khi thanh toán, dịch vụ chốt mô phỏng và kiểm tra lại báo giá vì việc
## chốt có thể trả lương hoặc kích hoạt callback làm thay đổi trạng thái.

## Phát sau khi trừ tiền và tăng cấp, gồm hướng, cấp mới và giá.
signal purchased(track: String, level: int, price: int)
## Danh mục giá nâng cấp công nhân.
const CATALOG: WorkerUpgradeCatalog = preload("res://resources/workers/upgrades.tres")
## Dịch vụ công nhân sở hữu trạng thái nâng cấp và thế giới.
var workers: WorkerService
## Cho biết giao dịch mua đang được xử lý.
var purchasing: bool = false

func _init(team: WorkerService) -> void:
	workers = team

## Trả báo giá có hướng, cấp hiện tại, cấp kế tiếp và giá.
## Trường [code]ok[/code] false và [code]error[/code] mô tả trường hợp hướng
## không hợp lệ, đã tối đa, công nhân không sẵn sàng hoặc không đủ xu.
func quote(track: String) -> Dictionary:
	if not track in WorkerUpgradeState.TRACKS:
		return {"ok": false, "error": "Unknown worker upgrade."}
	var current: int = workers.upgrades.level(track)
	var offer: Dictionary = {"ok": true, "track": track, "current": current, "next": current + 1, "price": CATALOG.price(track, current)}
	if current >= WorkerUpgradeState.maximum(track):
		offer.merge({"ok": false, "error": "Fully upgraded."}, true)
	elif purchasing or workers.busy or not workers.available():
		offer.merge({"ok": false, "error": "Workers are unavailable."}, true)
	elif offer.price < 0 or workers.world.player.wallet.balance < int(offer.price):
		offer.merge({"ok": false, "error": "Not enough coins."}, true)
	return offer

## Mua nâng cấp nếu cấp và giá vẫn khớp báo giá người gọi đã thấy.
## Chốt thời gian công nhân, kiểm tra lại, trừ xu rồi tăng cấp trước khi phát
## signal. Trả dictionary lỗi khi điều kiện thay đổi hoặc thanh toán thất bại.
func purchase(track: String, expected_level: int, expected_price: int) -> Dictionary:
	var offer: Dictionary = quote(track)
	if not offer.ok:
		return offer
	if offer.current != expected_level or offer.price != expected_price:
		return {"ok": false, "error": "The upgrade offer changed. Please try again."}
	workers.settle(workers.world.farming.time_manager.now())
	# Settle can pay wages or invoke observers; recheck the complete offer.
	offer = quote(track)
	if not offer.ok or offer.current != expected_level or offer.price != expected_price:
		return {"ok": false, "error": "The upgrade offer changed. Please try again."}
	purchasing = true
	workers.busy = true
	var wallet: WalletComponent = workers.world.player.wallet
	var previous: int = wallet.balance
	if not wallet.set_balance(previous - int(offer.price), false):
		workers.busy = false
		purchasing = false
		return {"ok": false, "error": "Not enough coins."}
	workers.upgrades.levels[track] = int(offer.next)
	wallet.changed.emit(wallet.balance)
	purchased.emit(track, int(offer.next), int(offer.price))
	workers.changed.emit()
	workers.busy = false
	purchasing = false
	return offer
