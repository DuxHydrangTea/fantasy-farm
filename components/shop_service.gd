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
		return {"ok": false, "error": "Invalid item or quantity."}
	var total: int = offer.price * quantity
	if wallet == null or inventory == null:
		return {"ok": false, "error": "Trading is unavailable."}
	if wallet.balance < total:
		return {"ok": false, "error": "Not enough coins.", "total": total}
	if inventory.capacity_for(offer.item) < quantity:
		return {"ok": false, "error": "Not enough inventory space.", "total": total}
	return {"ok": true, "total": total}

# GIAO DỊCH OFFLINE — báo giá không phải cam kết: luôn kiểm tra lại khi bấm Mua.
# Chuẩn bị bản sao các slot và xác nhận chứa đủ toàn bộ số mua trước khi chạm ví/túi thật.
# Nếu chỉ inventory.add rồi trừ tổng giá, túi gần đầy có thể nhận một phần nhưng bị tính tiền cả gói.
# _busy chặn listener của changed/purchased gọi Mua lồng nhau trong lúc đang commit.
# Đây là lệnh đồng bộ trên main thread; sau này online vẫn cần giao dịch nguyên tử ở server.
func buy(offer: ShopOffer, quantity: int) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "A trade is in progress."}
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
		return {"ok": false, "error": "Your inventory has changed."}
	_busy = true
	var previous: int = wallet.balance
	# Đổi ví trước nhưng tạm chưa phát signal; replace_slots sau đó phát inventory.changed
	# thì listener đã nhìn thấy cả ví mới lẫn túi mới. Nếu replace thất bại, trả ví về giá trị cũ.
	# Sau cùng mới thông báo ví/giao dịch. Nếu phát signal ngay giữa hai bước, UI hoặc listener
	# có thể quan sát trạng thái "đã có đồ nhưng chưa trừ xu" hoặc gọi mua lồng nhau.
	wallet.set_balance(previous - int(checked.total), false)
	if not inventory.replace_slots(stacks):
		wallet.set_balance(previous, false)
		_busy = false
		return {"ok": false, "error": "Unable to update your inventory."}
	# Inventory observers already see the debited wallet; no partial purchase.
	wallet.changed.emit(wallet.balance)
	purchased.emit(offer, quantity, int(checked.total))
	_busy = false
	return {"ok": true, "total": checked.total, "quantity": quantity}
