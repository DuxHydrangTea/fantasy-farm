class_name OrderService
extends RefCounted
## Deterministic rotation and atomic full delivery. No timers or offline rerolls.
signal changed
const DEFAULT_CATALOG: OrderCatalog = preload("res://resources/orders/farm_orders.tres")
const SALE_PRICES: ProducePriceCatalog = preload("res://resources/shops/produce_prices.tres")
const PERFECT_SALE_PERCENT: int = 110
var catalog: OrderCatalog
var inventory: InventoryComponent
var wallet: WalletComponent
var eligibility: Callable
var _data: Dictionary = OrderSaveSchema.fresh()
var _busy: bool = false

func _init(bag: InventoryComponent, purse: WalletComponent, available: Callable, definitions: OrderCatalog = DEFAULT_CATALOG) -> void:
	assert(definitions.is_valid())
	inventory = bag
	wallet = purse
	eligibility = available
	catalog = definitions

func initialize() -> void:
	if not _data.initialized:
		fill_empty()

func capture() -> Dictionary:
	return _data.duplicate(true)

func restore(data: Dictionary) -> bool:
	if _busy or not OrderSaveSchema.valid(data, catalog):
		return false
	_busy = true
	_data = data.duplicate(true)
	_data.next_serial = int(_data.next_serial)
	_data.cursor = int(_data.cursor)
	_data.completed = int(_data.completed)
	for row: Dictionary in _data.slots:
		if not row.is_empty():
			row.serial = int(row.serial)
	if not _data.initialized:
		_data.initialized = true
		for index: int in range(3):
			_fill(index)
	changed.emit()
	_busy = false
	return true

func _fill(index: int) -> void:
	if _data.next_serial >= 1000000000:
		return
	for offset: int in range(catalog.entries.size()):
		var next: int = (int(_data.cursor) + offset) % catalog.entries.size()
		var entry: OrderDefinition = catalog.entries[next]
		var already_active: bool = false
		for row: Dictionary in _data.slots:
			already_active = already_active or row.get("template", "") == String(entry.order_id)
		if already_active or not eligibility.is_valid() or not bool(eligibility.call(entry)):
			continue
		_data.slots[index] = {"serial": int(_data.next_serial), "template": String(entry.order_id)}
		_data.next_serial += 1
		_data.cursor = (next + 1) % catalog.entries.size()
		return

func fill_empty() -> void:
	if _busy:
		return
	_busy = true
	_data.initialized = true
	for index: int in range(3):
		if _data.slots[index].is_empty():
			_fill(index)
	changed.emit()
	_busy = false

func _index(serial: int) -> int:
	for index: int in range(3):
		if int(_data.slots[index].get("serial", 0)) == serial and serial > 0:
			return index
	return -1

func definition(serial: int) -> OrderDefinition:
	var index: int = _index(serial)
	return catalog.find(StringName(_data.slots[index].template)) if index >= 0 else null

func quote(serial: int, perfect: bool = false) -> Dictionary:
	var entry: OrderDefinition = definition(serial)
	if entry == null:
		return {"ok":false,"error":"This order has changed. Select it again."}
	var rows: Array[Dictionary] = []
	var sale_coins: int = 0
	for index: int in range(entry.items.size()):
		var id: StringName = entry.items[index].item_id
		var needed: int = entry.amounts[index]
		var tiers: Array[int] = [0,0,0]
		if perfect:
			tiers[1] = mini(needed,inventory.count_item(id,1))
			tiers[2] = mini(needed-tiers[1],inventory.count_item(id,2))
		else:
			tiers[0] = mini(needed,inventory.count_item(id,0))
		if tiers[0]+tiers[1]+tiers[2] != needed:
			return {"ok":false,"error":"Perfect delivery needs every requested item in Silver or Gold." if perfect else "Not enough items for this order."}
		if perfect:
			var price: ProducePrice = SALE_PRICES.find(id)
			if price == null:
				return {"ok":false,"error":"This product has no sale price. Perfect delivery is unavailable."}
			for tier: int in range(3):
				sale_coins += ItemQuality.unit_price(price.price,tier)*tiers[tier]
		rows.append({"item":String(id),"tiers":tiers})
	var coins: int = roundi(entry.reward_coins*1.5) if perfect else entry.reward_coins
	if perfect:
		coins = maxi(coins,ceili(float(sale_coins)*PERFECT_SALE_PERCENT/100.0))
	if coins > WalletComponent.MAX_COINS-wallet.balance:
		return {"ok":false,"error":"Your wallet has reached its coin limit."}
	return {"ok":true,"coins":coins,"perfect":perfect,"serial":serial,"rows":rows,"sale_coins":sale_coins}

func deliver(serial: int, perfect: bool = false, expected: Dictionary = {}) -> Dictionary:
	if _busy:
		return {"ok":false,"error":"A trade is in progress."}
	var plan: Dictionary = quote(serial,perfect)
	if not plan.ok:
		return plan
	if not expected.is_empty() and expected != plan:
		return {"ok":false,"error":"The ingredient tiers changed. Review the preview and confirm again."}
	_busy = true
	var entry: OrderDefinition = definition(serial)
	for index: int in range(entry.items.size()):
		inventory.consume(entry.items[index].item_id,entry.amounts[index],ItemQuality.tier_set([1,2]) if perfect else ItemQuality.exact(),false)
	wallet.set_balance(wallet.balance+int(plan.coins),false)
	var slot: int = _index(serial)
	_data.slots[slot] = {}
	_data.completed += 1
	_fill(slot)
	inventory.changed.emit()
	wallet.changed.emit(wallet.balance)
	changed.emit()
	_busy = false
	return plan

func abandon(serial: int) -> Dictionary:
	if _busy or _index(serial) < 0:
		return {"ok": false, "error": "This order has changed. Select it again."}
	_busy = true
	var index: int = _index(serial)
	_data.slots[index] = {}
	_fill(index)
	changed.emit()
	_busy = false
	return {"ok": true}

func requested_in_bag() -> bool:
	for row: Dictionary in _data.slots:
		if row.is_empty():
			continue
		for item: ItemDefinition in definition(int(row.serial)).items:
			if inventory.count_item(item.item_id,-1) > 0:
				return true
	return false
