class_name ToolUpgradeService
extends RefCounted
## Transactions shared by vendors. Both models commit before observers run.
signal purchased(tool: StringName, level: int, price: int)
var state: ToolUpgradeState
var wallet: WalletComponent
var land: LandExpansionState
var catalog: ToolUpgradeCatalog
var profile_ready: bool = false
var purchasing_enabled: bool = false # U4 enables purchases once area actions/preview exist.

func _init(progress: ToolUpgradeState, coins: WalletComponent, ownership: LandExpansionState, offers: ToolUpgradeCatalog) -> void:
	state = progress
	wallet = coins
	land = ownership
	catalog = offers

func _failure(code: String, error: String, offer: Dictionary = {}) -> Dictionary:
	return offer.merged({"ok": false, "code": code, "error": error}, true)

func quote(tool: StringName) -> Dictionary:
	if state == null or not is_instance_valid(wallet) or land == null or catalog == null:
		return _failure("unavailable", "Tool upgrades are unavailable.")
	if state.is_busy():
		return _failure("busy", "A tool upgrade is in progress.")
	if not purchasing_enabled or not profile_ready:
		return _failure("unavailable", "Tool upgrades are not available yet.")
	if not tool in ToolUpgradeState.TOOLS:
		return _failure("unknown_tool", "Unknown tool upgrade.")
	if not catalog.valid():
		return _failure("invalid_catalog", "Invalid tool upgrade catalog.")
	var current: int = state.level(tool)
	if current >= ToolUpgradeState.MAX_LEVEL:
		return _failure("max_level", "This tool is already fully upgraded.")
	var offer: ToolUpgradeOffer = catalog.find(tool, current + 1)
	var columns: int = land.unlocked_columns - land.starting_columns
	var result: Dictionary = {"ok": true, "tool": String(tool), "current_level": current, "next_level": current + 1,
		"price": offer.price, "required_columns": offer.required_purchased_columns, "purchased_columns": columns}
	if columns < offer.required_purchased_columns:
		return _failure("land_locked", "Unlock more farmland before upgrading this tool.", result)
	if wallet.balance < offer.price:
		return _failure("insufficient_coins", "Not enough coins.", result)
	return result

func purchase(tool: StringName, expected_level: int, expected_price: int) -> Dictionary:
	var offer: Dictionary = quote(tool)
	if not offer.ok:
		return offer
	if offer.current_level != expected_level or offer.price != expected_price:
		return _failure("stale_offer", "The tool upgrade offer changed. Please try again.")
	if not state.begin_purchase():
		return _failure("busy", "A tool upgrade is in progress.")
	var previous_balance: int = wallet.balance
	if not wallet.set_balance(previous_balance - int(offer.price), false):
		state.end_purchase()
		return _failure("unavailable", "Unable to spend coins.")
	if not state.commit_upgrade(tool, expected_level):
		wallet.set_balance(previous_balance, false)
		state.end_purchase()
		return _failure("stale_offer", "The tool upgrade offer changed. Please try again.")
	# Shared state lock also blocks a callback buying through another vendor.
	wallet.changed.emit(wallet.balance)
	state.changed.emit(tool)
	purchased.emit(tool, state.level(tool), int(offer.price))
	state.end_purchase()
	return {"ok": true, "tool": String(tool), "level": state.level(tool), "price": offer.price}
