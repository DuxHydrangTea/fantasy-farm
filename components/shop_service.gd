class_name ShopService
extends RefCounted
## Narrow purchase command. Stage the entire bag before committing either model.
signal purchased(offer: ShopOffer, quantity: int, total: int)
var catalog: ShopCatalog
var wallet: WalletComponent
var inventory: InventoryComponent
var _busy: bool = false

func _init(stock: ShopCatalog, purse: WalletComponent, bag: InventoryComponent) -> void:
	catalog = stock
	wallet = purse
	inventory = bag

func quote(offer: ShopOffer, quantity: int) -> Dictionary:
	if offer == null or catalog == null or not catalog.offers.has(offer) or offer.item == null or offer.item.item_id.is_empty() or offer.price < 1 or offer.price > 1000000 or quantity < 1 or quantity > 99:
		return {"ok": false, "error": "Mặt hàng hoặc số lượng không hợp lệ."}
	var total: int = offer.price * quantity
	if wallet == null or inventory == null:
		return {"ok": false, "error": "Chưa thể giao dịch."}
	if wallet.balance < total:
		return {"ok": false, "error": "Bạn không đủ xu.", "total": total}
	if inventory.capacity_for(offer.item) < quantity:
		return {"ok": false, "error": "Túi đồ không đủ chỗ.", "total": total}
	return {"ok": true, "total": total}

func buy(offer: ShopOffer, quantity: int) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "Đang xử lý giao dịch."}
	var checked: Dictionary = quote(offer, quantity)
	if not checked.ok:
		return checked
	var stacks: Array[Dictionary] = []
	for index: int in range(inventory.slot_count):
		stacks.append(inventory.slot(index))
	var left: int = quantity
	for stack: Dictionary in stacks:
		if stack.item != null and offer.item.matches(stack.item):
			var moved: int = mini(left, offer.item.get_stack_limit() - int(stack.count))
			stack.count += moved
			left -= moved
	for stack: Dictionary in stacks:
		if stack.item == null and left > 0:
			var moved: int = mini(left, offer.item.get_stack_limit())
			stack.item = offer.item
			stack.count = moved
			left -= moved
	if left != 0:
		return {"ok": false, "error": "Túi đồ đã thay đổi."}
	_busy = true
	var previous: int = wallet.balance
	wallet.set_balance(previous - int(checked.total), false)
	if not inventory.replace_slots(stacks):
		wallet.set_balance(previous, false)
		_busy = false
		return {"ok": false, "error": "Không thể cập nhật túi đồ."}
	# Inventory observers already see the debited wallet; no partial purchase.
	wallet.changed.emit(wallet.balance)
	purchased.emit(offer, quantity, int(checked.total))
	_busy = false
	return {"ok": true, "total": checked.total, "quantity": quantity}
