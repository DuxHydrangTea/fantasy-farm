class_name WorkerUpgradeService
extends RefCounted
signal purchased(track: String, level: int, price: int)
const CATALOG: WorkerUpgradeCatalog = preload("res://resources/workers/upgrades.tres")
var workers: WorkerService
var purchasing: bool = false

func _init(team: WorkerService) -> void:
	workers = team

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
