class_name TreePlotUpgradeState
extends RefCounted
signal changed(kind: TreeDefinition.Kind)
const CATALOG: TreePlotUpgradeCatalog = preload("res://resources/trees/plot_upgrades.tres")
const MAX_LEVEL: int = 17
const SLOTS_PER_LEVEL: int = 9
var _levels: Dictionary = fresh()
var _busy: bool = false

static func fresh() -> Dictionary:
	var result: Dictionary = {}
	for id: String in ["fruit", "timber"]:
		result[id] = 1
	return result

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != ["fruit", "timber"].size():
		return false
	for id: String in ["fruit", "timber"]:
		var value: Variant = data.get(id)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 1 or value > MAX_LEVEL or float(value) != floor(float(value)):
			return false
	return true

static func key(kind: TreeDefinition.Kind) -> String:
	return "fruit" if kind == TreeDefinition.Kind.FRUIT else "timber"

static func column(cell: Vector2i, kind: TreeDefinition.Kind) -> int:
	return floori(float(cell.x - TreePlantation.region_for(kind).position.x - 2) / 3.0)

static func allows(data: Dictionary, cell: Vector2i, kind: TreeDefinition.Kind) -> bool:
	return TreePlantation.valid_cell(cell, kind) and column(cell, kind) < int(data.get(key(kind), 0))

static func migrate(rows: Variant, catalog: SaveCatalog) -> Dictionary:
	if not rows is Array:
		return {}
	var result: Dictionary = fresh()
	for row: Variant in rows:
		if not row is Dictionary or not row.get("tree") is String or not catalog.trees.has(row.tree) or not SaveSchema.vector(row.get("cell"), true):
			return {}
		var definition: TreeDefinition = catalog.trees[row.tree]
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		if not TreePlantation.valid_cell(cell, definition.kind):
			return {}
		result[key(definition.kind)] = maxi(int(result[key(definition.kind)]), column(cell, definition.kind) + 1)
	return result

func level(kind: TreeDefinition.Kind) -> int:
	return int(_levels.get(key(kind), 0))

func capacity(kind: TreeDefinition.Kind) -> int:
	return level(kind) * SLOTS_PER_LEVEL

func capture() -> Dictionary:
	return _levels.duplicate(true)

func restore(data: Dictionary) -> bool:
	if _busy or not valid(data):
		return false
	_levels = data.duplicate(true)
	return true

func is_busy() -> bool:
	return _busy

func begin_purchase() -> bool:
	if _busy:
		return false
	_busy = true
	return true

func commit(kind: TreeDefinition.Kind, expected_level: int) -> bool:
	if not _busy or level(kind) != expected_level or expected_level < 1 or expected_level >= MAX_LEVEL:
		return false
	_levels[key(kind)] = expected_level + 1
	return true

func end_purchase() -> void:
	_busy = false
