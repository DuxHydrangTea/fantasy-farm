class_name EconomySaveSchema
extends RefCounted
## v15 -> v16 preserves issued orders, existing timers and all retained feed units.
const NEW_TROUGHS: Array[Dictionary] = [
	{"id": "barn_feedtrough_02", "source": "placed_1563140842", "position": [96, 192]},
	{"id": "barn_watertrough_02", "source": "placed_203535476", "position": [144, 192]},
	{"id": "pond_feedtrough_02", "source": "pond_feedtrough", "position": [48, 72]},
	{"id": "pond_watertrough_02", "source": "pond_watertrough", "position": [112, 72]}
]
const FOOD_IDS: Array[String] = ["placed_2042315591", "placed_144181841", "placed_1563140842", "barn_feedtrough_02", "pond_feedtrough", "pond_feedtrough_02"]

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
