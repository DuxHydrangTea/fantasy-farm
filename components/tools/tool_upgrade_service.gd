class_name ToolUpgradeService
extends RefCounted
## Transactions shared by vendors. Both models commit before observers run.
signal purchased(tool: StringName, level: int, price: int)
var inventory: InventoryComponent
var world: FarmWorld
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
	if state.is_busy() or (world != null and ((world.tree_plot_upgrades != null and world.tree_plot_upgrades.state.is_busy()) or world.storages.busy or world.wood_market.busy or world.workers.busy or (world.pen_upgrades != null and world.pen_upgrades.state.is_busy()))):
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
		"price": offer.price, "wood_cost": offer.wood_cost, "wood_owned": wood_owned(), "required_columns": offer.required_purchased_columns, "purchased_columns": columns}
	if columns < offer.required_purchased_columns:
		return _failure("land_locked", "Unlock more farmland before upgrading this tool.", result)
	if wallet.balance < offer.price:
		return _failure("insufficient_coins", "Not enough coins.", result)
	if wood_owned() < offer.wood_cost:
		return _failure("insufficient_wood", "Not enough wood in your warehouse and bag.", result)
	return result

func purchase(tool: StringName, expected_level: int, expected_price: int, expected_wood: int = -1) -> Dictionary:
	var offer: Dictionary = quote(tool)
	if not offer.ok:
		return offer
	if offer.current_level != expected_level or offer.price != expected_price or (expected_wood >= 0 and expected_wood != int(offer.wood_cost)):
		return _failure("stale_offer", "The tool upgrade offer changed. Please try again.")
	if not state.begin_purchase():
		return _failure("busy", "A tool upgrade is in progress.")
	if world != null:
		world.storages.busy = true
	var bags: Array[InventoryComponent] = wood_sources()
	var snapshots: Array = []
	for bag: InventoryComponent in bags:
		var slots: Array[Dictionary] = []
		for i: int in range(bag.slot_count):
			slots.append(bag.slot(i))
		snapshots.append(slots)
	var remaining: int = int(offer.wood_cost)
	for bag: InventoryComponent in bags:
		remaining -= bag.remove(WoodMarket.ITEM, remaining, false)
	var previous_balance: int = wallet.balance
	if remaining > 0 or not wallet.set_balance(previous_balance - int(offer.price), false):
		_restore_wood(bags, snapshots)
		_end_purchase()
		return _failure("unavailable", "Unable to spend coins.")
	if not state.commit_upgrade(tool, expected_level):
		wallet.set_balance(previous_balance, false)
		_restore_wood(bags, snapshots)
		_end_purchase()
		return _failure("stale_offer", "The tool upgrade offer changed. Please try again.")
	# Shared state lock also blocks a callback buying through another vendor.
	for bag: InventoryComponent in bags:
		if offer.wood_cost > 0:
			bag.changed.emit()
	wallet.changed.emit(wallet.balance)
	state.changed.emit(tool)
	purchased.emit(tool, state.level(tool), int(offer.price))
	_end_purchase()
	return {"ok": true, "tool": String(tool), "level": state.level(tool), "price": offer.price, "wood_cost": offer.wood_cost}

func wood_sources() -> Array[InventoryComponent]:
	var result: Array[InventoryComponent] = []
	if world != null and world.storages != null:
		result.append(world.storages.inventory("produce_warehouse"))
	if is_instance_valid(inventory) and not result.has(inventory):
		result.append(inventory)
	return result

func wood_owned() -> int:
	var total: int = 0
	for bag: InventoryComponent in wood_sources():
		total += bag.count_item(WoodMarket.ITEM)
	return total

func _restore_wood(bags: Array[InventoryComponent], snapshots: Array) -> void:
	for i: int in range(bags.size()):
		bags[i].replace_slots(snapshots[i], false)

func _end_purchase() -> void:
	if world != null:
		world.storages.busy = false
	state.end_purchase()
