class_name OrderSaveSchema
extends RefCounted

static func fresh() -> Dictionary:
	return {"initialized": false, "next_serial": 1, "cursor": 0, "completed": 0, "slots": [{}, {}, {}]}

static func valid(data: Variant, catalog: OrderCatalog) -> bool:
	if not data is Dictionary or data.size() != 5 or not data.get("initialized") is bool or not data.get("slots") is Array or data.slots.size() != 3:
		return false
	if not SaveSchema.number(data.get("next_serial"), 1, 1000000000, true) or not SaveSchema.number(data.get("cursor"), 0, catalog.entries.size() - 1, true) or not SaveSchema.number(data.get("completed"), 0, float(data.next_serial) - 1, true):
		return false
	var serials: Dictionary = {}
	var templates: Dictionary = {}
	for row: Variant in data.slots:
		if not row is Dictionary:
			return false
		if row.is_empty():
			continue
		if row.size() != 2 or not row.get("template") is String or catalog.find(StringName(row.template)) == null or not SaveSchema.number(row.get("serial"), 1, float(data.next_serial) - 1, true):
			return false
		if serials.has(int(row.serial)) or templates.has(row.template):
			return false
		serials[int(row.serial)] = true
		templates[row.template] = true
	if not data.initialized and (data.next_serial != 1 or data.cursor != 0 or data.completed != 0 or not serials.is_empty()):
		return false
	return int(data.completed) + serials.size() < int(data.next_serial)
