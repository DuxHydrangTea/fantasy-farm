class_name ProduceSaleService
extends RefCounted
## Fixed-price produce sales; stage the complete inventory before crediting coins.
signal sold(quantity: int, total: int)
var catalog: ProducePriceCatalog
var wallet: WalletComponent
var inventory: InventoryComponent
var _busy: bool = false
var tier: int = 0

func _init(prices: ProducePriceCatalog, purse: WalletComponent, bag: InventoryComponent) -> void:
	catalog = prices
	wallet = purse
	inventory = bag

func quantity(entry: ProducePrice) -> int:
	if entry == null or not entry.is_valid() or not is_instance_valid(inventory):
		return 0
	var count: int = 0
	for index: int in range(inventory.slot_count):
		var stack: Dictionary = inventory.slot(index)
		if _matches(stack.item, entry):
			count += int(stack.tiers[tier]) if tier >= 0 and tier <= 2 else 0
	return count

func owned_entries() -> Array[ProducePrice]:
	var result: Array[ProducePrice] = []
	if catalog != null and catalog.is_valid():
		for entry: ProducePrice in catalog.entries:
			if quantity(entry) > 0:
				result.append(entry)
	return result

func _matches(item: ItemDefinition, entry: ProducePrice) -> bool:
	return item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and item.matches(entry.item)

func quote(entry: ProducePrice, amount: int) -> Dictionary:
	return _prepare(entry, amount, false)

func quote_all() -> Dictionary:
	return _prepare(null, 0, true)

func sell(entry: ProducePrice, amount: int) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "A trade is in progress."}
	return _commit(_prepare(entry, amount, false))

func sell_all() -> Dictionary:
	if _busy:
		return {"ok": false, "error": "A trade is in progress."}
	return _commit(_prepare(null, 0, true))

func _prepare(entry: ProducePrice, amount: int, all_produce: bool) -> Dictionary:
	if tier < 0 or tier > 2 or catalog == null or not catalog.is_valid() or not is_instance_valid(wallet) or not is_instance_valid(inventory):
		return {"ok": false, "error": "Produce trading is unavailable."}
	if not all_produce and (entry == null or not catalog.entries.has(entry) or amount < 1):
		return {"ok": false, "error": "Invalid item or quantity."}
	var stacks: Array[Dictionary] = []
	var total: int = 0
	var count: int = 0
	var left: int = amount
	for index: int in range(inventory.slot_count):
		var stack: Dictionary = inventory.slot(index)
		var price: ProducePrice = catalog.find(stack.item.item_id) if stack.item != null else null
		if price != null and _matches(stack.item, price) and (all_produce or price == entry):
			var removed: int = int(stack.tiers[tier]) if all_produce else mini(left, int(stack.tiers[tier]))
			count += removed
			total += removed * ItemQuality.unit_price(price.price, tier)
			left -= removed
			stack.count -= removed
			stack.tiers[tier] -= removed
			if stack.count == 0:
				stack.item = null
		stacks.append(stack)
	if not all_produce and left != 0:
		return {"ok": false, "error": "Not enough produce."}
	if count == 0:
		return {"ok": false, "error": "No produce to sell."}
	if total > WalletComponent.MAX_COINS - wallet.balance:
		return {"ok": false, "error": "Your wallet has reached its coin limit.", "total": total, "quantity": count}
	return {"ok": true, "total": total, "quantity": count, "slots": stacks}

func _commit(plan: Dictionary) -> Dictionary:
	if not plan.ok:
		return plan
	_busy = true
	var previous: int = wallet.balance
	wallet.set_balance(previous + int(plan.total), false)
	# Inventory listeners see both models committed; reentrant sales remain blocked.
	if not inventory.replace_slots(plan.slots):
		wallet.set_balance(previous, false)
		_busy = false
		return {"ok": false, "error": "Unable to update your inventory."}
	wallet.changed.emit(wallet.balance)
	sold.emit(int(plan.quantity), int(plan.total))
	_busy = false
	return {"ok": true, "total": plan.total, "quantity": plan.quantity}
