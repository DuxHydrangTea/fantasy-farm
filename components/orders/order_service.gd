class_name OrderService
extends RefCounted
## Quản lý ba ô đơn hàng xoay vòng xác định và giao hàng toàn bộ.
## Đơn không tự đổi theo thời gian hoặc khi mô phỏng offline.

## Phát sau khi các ô đơn hoặc dữ liệu hoàn thành thay đổi.
signal changed
## Catalog đơn hiện hành mặc định.
const DEFAULT_CATALOG: OrderCatalog = preload("res://resources/orders/farm_orders.tres")
## Catalog giá dùng để tính mức thưởng giao hoàn hảo.
const SALE_PRICES: ProducePriceCatalog = preload("res://resources/shops/produce_prices.tres")
## Phần trăm giá bán tối thiểu được trả cho giao hàng hoàn hảo.
const PERFECT_SALE_PERCENT: int = 110
## Catalog định nghĩa đơn.
var catalog: OrderCatalog
## Túi chứa hàng giao.
var inventory: InventoryComponent
## Ví nhận thưởng.
var wallet: WalletComponent
## Hàm kiểm tra đơn có nguồn sản phẩm trong thế giới.
var eligibility: Callable
var _data: Dictionary = OrderSaveSchema.fresh()
var _busy: bool = false

func _init(bag: InventoryComponent, purse: WalletComponent, available: Callable, definitions: OrderCatalog = DEFAULT_CATALOG) -> void:
	assert(definitions.is_valid())
	inventory = bag
	wallet = purse
	eligibility = available
	catalog = definitions

## Điền các ô trống khi bảng chưa được khởi tạo.
func initialize() -> void:
	if not _data.initialized:
		fill_empty()

## Tạo bản sao sâu trạng thái bảng đơn để lưu.
func capture() -> Dictionary:
	return _data.duplicate(true)

## Kiểm tra và khôi phục bảng đơn; điền ô nếu dữ liệu chưa khởi tạo.
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

## Điền các ô trống bằng đơn đủ điều kiện theo con trỏ xoay vòng.
## Một mẫu không xuất hiện đồng thời ở nhiều ô.
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

## Tìm định nghĩa của đơn đang hoạt động theo serial, hoặc null.
func definition(serial: int) -> OrderDefinition:
	var index: int = _index(serial)
	return catalog.find(StringName(_data.slots[index].template)) if index >= 0 else null

## Tính kế hoạch giao đầy đủ và phần thưởng mà không thay đổi túi hoặc đơn.
## Giao thường dùng cấp thường; giao hoàn hảo dùng bạc trước vàng và thưởng
## ít nhất 110% tổng giá bán các vật phẩm theo chất lượng.
## Trả lỗi nếu thiếu hàng, thiếu giá hoặc ví không còn đủ chỗ.
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

## Kiểm tra lại kế hoạch, trừ hàng, cộng xu, thay đơn và phát thông báo.
## Nếu truyền expected, kế hoạch phải khớp bản xem trước để tránh giao nhầm cấp.
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

## Bỏ đơn đang hoạt động và thử chọn đơn thay thế theo vòng xoay.
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

## Cho biết túi có ít nhất một vật phẩm thuộc các đơn đang hoạt động ở bất kỳ cấp nào.
func requested_in_bag() -> bool:
	for row: Dictionary in _data.slots:
		if row.is_empty():
			continue
		for item: ItemDefinition in definition(int(row.serial)).items:
			if inventory.count_item(item.item_id,-1) > 0:
				return true
	return false
