class_name PenUpgradeState
extends RefCounted
signal changed(pen_id: StringName)
const CATALOG: PenUpgradeCatalog = preload("res://resources/animals/pen_upgrades.tres")
const MAX_LEVEL: int = 6
const SLOTS_PER_LEVEL: int = 5
var _levels: Dictionary = fresh()
var _busy: bool = false

static func fresh() -> Dictionary:
	var result: Dictionary = {}
	for id: String in CATALOG.pen_kinds:
		result[id] = 1
	return result

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != CATALOG.pen_kinds.size():
		return false
	for id: String in CATALOG.pen_kinds:
		var value: Variant = data.get(id)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 1 or value > MAX_LEVEL or float(value) != floor(float(value)):
			return false
	return true

static func migrate(animals: Variant) -> Dictionary:
	if not animals is Array:
		return {}
	var result: Dictionary = fresh()
	var populations: Dictionary = {}
	for row: Variant in animals:
		if not row is Dictionary or not row.get("pen") is String:
			return {}
		var id: String = row.pen
		populations[id] = int(populations.get(id, 0)) + 1
	for id: String in result:
		result[id] = clampi(ceili(float(populations.get(id, 0)) / SLOTS_PER_LEVEL), 1, MAX_LEVEL)
	return result

func level(id: StringName) -> int:
	return int(_levels.get(String(id), 0))

func capacity(id: StringName) -> int:
	return level(id) * SLOTS_PER_LEVEL

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

func commit(id: StringName, expected_level: int) -> bool:
	if not _busy or level(id) != expected_level or expected_level < 1 or expected_level >= MAX_LEVEL:
		return false
	_levels[String(id)] = expected_level + 1
	return true

func end_purchase() -> void:
	_busy = false
