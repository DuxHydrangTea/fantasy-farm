class_name QualitySaveSchema
extends RefCounted

static func slot_valid(slot: Variant, catalog: SaveCatalog, cap: int = 0) -> bool:
	if not slot is Dictionary or not slot.get("item") is String or not SaveSchema.number(slot.get("count"), 0, 32000, true):
		return false
	var item: ItemDefinition = catalog.items.get(slot.item) as ItemDefinition
	if slot.item.is_empty():
		if slot.count != 0:
			return false
	elif item == null or slot.count < 1 or slot.count > (mini(cap, item.get_stack_limit()) if cap > 0 else item.get_stack_limit()):
		return false
	return ItemQuality.valid_tiers(slot.get("tiers"), item, int(slot.count))

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
