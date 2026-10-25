class_name ToolUpgradeState
extends RefCounted
## Profile progress, independent of inventory items and NPCs.
signal changed(tool: StringName)
const TOOLS: Array[StringName] = [&"hoe", &"watering_can", &"sowing"]
const MAX_LEVEL: int = 6
var _progress: Dictionary = fresh()
var _busy: bool = false

static func fresh() -> Dictionary:
	return {"hoe": {"level": 1, "selected_size": 1}, "watering_can": {"level": 1, "selected_size": 1}, "sowing": {"level": 1, "selected_size": 1}}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != TOOLS.size():
		return false
	for tool: StringName in TOOLS:
		var row: Variant = data.get(String(tool))
		if not row is Dictionary or row.size() != 2 or not _integer(row.get("level"), 1, MAX_LEVEL):
			return false
		if not _integer(row.get("selected_size"), 1, int(row.level)):
			return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and float(value) == floor(float(value))

func level(tool: StringName) -> int:
	return int(_progress[String(tool)].level) if tool in TOOLS else 0

func selected_size(tool: StringName) -> int:
	return int(_progress[String(tool)].selected_size) if tool in TOOLS else 0

func select_size(tool: StringName, size: int) -> bool:
	if _busy or not tool in TOOLS or size < 1 or size > level(tool):
		return false
	if selected_size(tool) != size:
		_progress[String(tool)].selected_size = size
		changed.emit(tool)
	return true

func capture() -> Dictionary:
	return _progress.duplicate(true)

func restore(data: Dictionary, notify: bool = true) -> bool:
	if _busy or not valid(data):
		return false
	var next: Dictionary = {}
	for tool: StringName in TOOLS:
		var row: Dictionary = data[String(tool)]
		next[String(tool)] = {"level": int(row.level), "selected_size": int(row.selected_size)}
	_progress = next
	if notify:
		notify_restored()
	return true

func notify_restored() -> void:
	for tool: StringName in TOOLS:
		changed.emit(tool)

func is_busy() -> bool:
	return _busy

func begin_purchase() -> bool:
	if _busy:
		return false
	_busy = true
	return true

func commit_upgrade(tool: StringName, expected_level: int) -> bool:
	if not _busy or not tool in TOOLS or level(tool) != expected_level or expected_level >= MAX_LEVEL:
		return false
	_progress[String(tool)] = {"level": expected_level + 1, "selected_size": expected_level + 1}
	return true

func end_purchase() -> void:
	_busy = false
