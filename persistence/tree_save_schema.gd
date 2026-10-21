class_name TreeSaveSchema
extends RefCounted
## Kiểm tra toàn bộ cây trước khi thay đổi thế giới hoặc túi đồ.
static func valid(rows: Variant, catalog: SaveCatalog, saved_at: float) -> bool:
	if not rows is Array or rows.size() > 1000:
		return false
	var cells: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary or not row.get("tree") is String or not catalog.trees.has(row.tree) or not SaveSchema.vector(row.get("cell"), true):
			return false
		var definition: TreeDefinition = catalog.trees[row.tree]
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		if not TreePlantation.valid_cell(cell, definition.kind) or cells.has(cell):
			return false
		cells[cell] = true
		for key: String in ["planted_at", "matures_at", "last_at"]:
			if not SaveSchema.number(row.get(key)):
				return false
		if not SaveSchema.number(row.get("growth_started_at"), -1) or row.last_at > saved_at or row.planted_at > row.last_at:
			return false
		if row.growth_started_at == -1.0:
			if definition.kind != TreeDefinition.Kind.FRUIT or row.matures_at != 0.0:
				return false
		elif row.growth_started_at < row.planted_at or row.growth_started_at > row.last_at or row.matures_at <= row.growth_started_at:
			return false
		else:
			var duration: float = float(row.matures_at) - float(row.growth_started_at)
			if not is_equal_approx(duration, definition.growth_seconds) and not (definition.kind == TreeDefinition.Kind.TIMBER and is_equal_approx(duration, definition.growth_seconds * 0.5)):
				return false
		if definition.kind == TreeDefinition.Kind.FRUIT:
			if not SaveSchema.number(row.get("fruit_work"), 0, definition.fruit_cycle_seconds) or ((row.growth_started_at < 0 or row.last_at < row.matures_at) and row.fruit_work != 0):
				return false
		else:
			if not row.get("stump") is bool or not SaveSchema.number(row.get("hits"), 0, definition.chop_hits, true) or not SaveSchema.number(row.get("root_hits"), 0, definition.dig_hits - 1, true) or not SaveSchema.number(row.get("regrow_at")):
				return false
			if row.stump:
				if row.hits != definition.chop_hits or row.regrow_at <= row.last_at or row.last_at < row.matures_at:
					return false
			elif row.hits >= definition.chop_hits or row.root_hits != 0 or row.regrow_at != 0:
				return false
	return true
