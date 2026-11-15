class_name EconomySaveSchema
extends RefCounted
## Chuyển dữ liệu kinh tế từ phiên bản 15 sang 16.
## Bảo toàn đơn đã phát hành, các mốc thời gian và lượng thức ăn được giữ lại.

## Các máng mới được tạo từ chuồng của máng nguồn nếu máng nguồn tồn tại.
const NEW_TROUGHS: Array[Dictionary] = [
	{"id": "barn_feedtrough_02", "source": "placed_1563140842", "position": [96, 192]},
	{"id": "barn_watertrough_02", "source": "placed_203535476", "position": [144, 192]},
	{"id": "pond_feedtrough_02", "source": "pond_feedtrough", "position": [48, 72]},
	{"id": "pond_watertrough_02", "source": "pond_watertrough", "position": [112, 72]}
]
## Mã các máng thức ăn cần gộp lượng dự trữ cũ vào stock.
const FOOD_IDS: Array[String] = ["placed_2042315591", "placed_144181841", "placed_1563140842", "barn_feedtrough_02", "pond_feedtrough", "pond_feedtrough_02"]

## Chuyển dữ liệu tại chỗ, kiểm tra đơn cũ rồi điều chỉnh con trỏ theo catalog mới.
## Trả dictionary có [code]ok[/code] hoặc lỗi từ SaveSchema. Khi lỗi, dữ liệu
## đầu vào có thể đã được thay đổi một phần.
static func migrate(data: Dictionary) -> Dictionary:
	if not data.get("troughs") is Array or not data.get("orders") is Dictionary:
		return SaveSchema.failure("Invalid legacy economy state.")
	var by_id: Dictionary = {}
	for row: Variant in data.troughs:
		if not row is Dictionary or not SaveSchema.identifier(row.get("id")):
			return SaveSchema.failure("Invalid legacy trough.")
		if by_id.has(row.id):
			return SaveSchema.failure("Invalid legacy trough.")
		by_id[row.id] = row
		if row.id in FOOD_IDS and SaveSchema.number(row.get("stock"), 0, 600, true) and SaveSchema.number(row.get("feed_reserve"), 0, 299, true):
			row.stock += row.feed_reserve
			row.feed_reserve = 0
	for addition: Dictionary in NEW_TROUGHS:
		if not by_id.has(addition.id) and by_id.has(addition.source):
			if not by_id[addition.source].get("pen") is String:
				return SaveSchema.failure("Invalid legacy trough.")
			data.troughs.append({"id": addition.id, "pen": by_id[addition.source].pen, "position": addition.position.duplicate(), "stock": 0, "feed_reserve": 0})
	var orders: Dictionary = data.orders
	var legacy: OrderCatalog = load("res://resources/orders/legacy_orders_v15.tres") as OrderCatalog
	var current: OrderCatalog = load("res://resources/orders/farm_orders.tres") as OrderCatalog
	if legacy == null or not OrderSaveSchema.valid(orders, legacy):
		return SaveSchema.failure("Invalid legacy order board state.")
	orders.cursor = int(orders.cursor) % current.entries.size()
	return {"ok": true}
