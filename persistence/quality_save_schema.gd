class_name QualitySaveSchema
extends RefCounted
## Kiểm tra và chuyển dữ liệu chất lượng vật phẩm trong các container lưu game.
##
## Mỗi ô chứa mã vật phẩm, tổng số lượng và mảng số lượng theo ba cấp chất lượng.
## Các hàm migrate và split thay đổi trực tiếp dữ liệu được truyền vào.

## Kiểm tra cấu trúc ô, mã trong catalog, giới hạn chồng và tổng theo cấp.
## Nếu [param cap] dương, giới hạn chồng còn bị chặn bởi giá trị này.
## [param allow_mixed] cho phép một ô chứa nhiều cấp trong dữ liệu cũ.
static func slot_valid(slot: Variant, catalog: SaveCatalog, cap: int = 0, allow_mixed: bool = false) -> bool:
	if not slot is Dictionary or not slot.get("item") is String or not SaveSchema.number(slot.get("count"), 0, 32000, true):
		return false
	var item: ItemDefinition = catalog.items.get(slot.item) as ItemDefinition
	if slot.item.is_empty():
		if slot.count != 0:
			return false
	elif item == null or slot.count < 1 or slot.count > (mini(cap, item.get_stack_limit()) if cap > 0 else item.get_stack_limit()):
		return false
	return ItemQuality.valid_tiers(slot.get("tiers"), item, int(slot.count)) and (allow_mixed or ItemQuality.homogeneous(slot.tiers))

## Thêm mảng cấp chất lượng mặc định vào các ô cũ chưa có trường tiers.
## Trả false khi danh sách hoặc số lượng không hợp lệ.
static func migrate_slots(slots: Variant) -> bool:
	if not slots is Array:
		return false
	for slot: Variant in slots:
		if not slot is Dictionary or not SaveSchema.number(slot.get("count"), 0, 32000, true):
			return false
		# Existing modern defaults may already carry tiers in very old migrations.
		if not slot.has("tiers"):
			slot["tiers"] = [int(slot.count), 0, 0]
	return true

## Bổ sung cấp chất lượng mặc định cho túi người chơi, kho và giỏ công nhân.
## Dữ liệu có thể đã được sửa một phần nếu một bước sau trả false.
static func migrate(data: Dictionary) -> bool:
	if not migrate_slots(data.get("inventory")) or not data.get("storages") is Dictionary or not data.get("workers") is Dictionary or not data.workers.get("rows") is Array:
		return false
	for storage: Variant in data.storages.values():
		if not storage is Dictionary or not migrate_slots(storage.get("slots")):
			return false
	for worker: Variant in data.workers.rows:
		if not worker is Dictionary or not migrate_slots(worker.get("basket")):
			return false
	return true

## Tách các chồng nhiều cấp thành các ô cùng cấp, giữ nguyên tổng số vật phẩm.
## Ưu tiên ô trống sẵn có và thêm ô khi cần. [param maximum] giới hạn kích thước
## danh sách đầu vào; các ô được thêm có thể làm danh sách dài hơn giới hạn đó.
static func split_legacy_slots(slots: Variant, catalog: SaveCatalog, cap: int = 0, maximum: int = 256) -> bool:
	if not slots is Array or slots.is_empty() or slots.size() > maximum:
		return false
	for slot: Variant in slots:
		if not slot_valid(slot, catalog, cap, true):
			return false
	var extras: Array[Dictionary] = []
	for slot: Dictionary in slots:
		if slot.item.is_empty():
			continue
		var first: int = ItemQuality.stack_tier(slot.tiers)
		for tier: int in range(3):
			if tier != first and int(slot.tiers[tier]) > 0:
				var separate: Dictionary = {"item": slot.item, "count": int(slot.tiers[tier]), "tiers": [0, 0, 0]}
				separate.tiers[tier] = separate.count
				extras.append(separate)
		var amount: int = int(slot.tiers[first])
		slot.count = amount
		slot.tiers = [0, 0, 0]
		slot.tiers[first] = amount
	for extra: Dictionary in extras:
		var empty: int = -1
		for index: int in range(slots.size()):
			if slots[index].item.is_empty():
				empty = index
				break
		if empty >= 0:
			slots[empty] = extra
		else:
			slots.append(extra)
	return true

## Tách chồng cũ trong túi, các kho và giỏ công nhân, cập nhật số ô của kho.
## Các thay đổi thực hiện tại chỗ, nên dữ liệu có thể đã sửa một phần khi lỗi.
static func split_legacy(data: Dictionary, catalog: SaveCatalog) -> bool:
	if not split_legacy_slots(data.get("inventory"), catalog) or not data.get("storages") is Dictionary or not data.get("workers") is Dictionary or not data.workers.get("rows") is Array:
		return false
	for row: Variant in data.storages.values():
		if not row is Dictionary or not SaveSchema.number(row.get("stack_cap"), 0, 32000, true) or not row.get("slots") is Array or row.slots.size() != row.get("slot_count") or not split_legacy_slots(row.slots, catalog, int(row.stack_cap), 512):
			return false
		row.slot_count = row.slots.size()
	for row: Variant in data.workers.rows:
		if not row is Dictionary or not row.get("basket") is Array or row.basket.size() != 16 or not split_legacy_slots(row.basket, catalog, 100, 16):
			return false
	return true
