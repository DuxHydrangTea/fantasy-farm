class_name CropAutomationState
extends RefCounted
## Primitive, bounded history survives reload; no stock or per-plot nodes here.
var revision: int = 0
var auto_plant: bool = false
var auto_fertilize: bool = false
var paused: bool = false
var wait_for_care: bool = true
var prepared: Dictionary[String, Vector2i] = {}
var sequence: int = 0
var plots: Dictionary[Vector2i, Dictionary] = {}

static func fresh() -> Dictionary:
	return {"revision": 0, "auto_plant": false, "auto_fertilize": false, "paused": false, "wait_for_care": true, "prepared": [], "sequence": 0, "plots": []}

func capture() -> Dictionary:
	var data: Dictionary = fresh()
	data.revision = revision
	data.auto_plant = auto_plant
	data.auto_fertilize = auto_fertilize
	data.paused = paused
	data.wait_for_care = wait_for_care
	var ids: Array[String] = prepared.keys()
	ids.sort()
	for id: String in ids:
		data.prepared.append({"worker": id, "cell": [prepared[id].x, prepared[id].y]})
	data.sequence = sequence
	var cells: Array[Vector2i] = plots.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var row: Dictionary = plots[cell]
		data.plots.append({"cell": [cell.x, cell.y], "last": int(row.last), "crop": String(row.crop), "planted_at": float(row.planted_at)})
	return data

func restore(data: Dictionary) -> void:
	revision = int(data.revision)
	auto_plant = data.auto_plant
	auto_fertilize = data.auto_fertilize
	paused = data.paused
	wait_for_care = data.wait_for_care
	sequence = int(data.sequence)
	prepared.clear()
	for row: Dictionary in data.prepared:
		prepared[row.worker] = Vector2i(int(row.cell[0]), int(row.cell[1]))
	plots.clear()
	for row: Dictionary in data.plots:
		plots[Vector2i(int(row.cell[0]), int(row.cell[1]))] = {"last": int(row.last), "crop": String(row.crop), "planted_at": float(row.planted_at)}

func remember(cell: Vector2i, crop: Crop) -> void:
	sequence += 1
	plots[cell] = {"last": sequence, "crop": String(crop.definition.crop_id), "planted_at": crop.planted_at}
	clear_prepared(cell)

func forget_crop(cell: Vector2i) -> void:
	if plots.has(cell):
		plots[cell].crop = ""
		plots[cell].planted_at = 0.0
	clear_prepared(cell)

func owns(cell: Vector2i, crop: Crop) -> bool:
	return crop != null and plots.has(cell) and String(plots[cell].crop) == String(crop.definition.crop_id) and float(plots[cell].planted_at) == crop.planted_at

func prepared_for(id: String) -> Vector2i:
	return prepared.get(id, Vector2i(-1, -1))

func clear_prepared(cell: Vector2i) -> void:
	for id: String in prepared.keys():
		if prepared[id] == cell:
			prepared.erase(id)

static func valid(data: Variant, catalog: SaveCatalog, saved_at: float) -> bool:
	if not data is Dictionary or data.size() != 8 or not data.get("wait_for_care") is bool or not SaveSchema.number(data.get("revision"), 0, 1.0e12, true) or not data.get("auto_plant") is bool or not data.get("auto_fertilize") is bool or not data.get("paused") is bool or not SaveSchema.number(data.get("sequence"), 0, 1.0e12, true) or not data.get("prepared") is Array or not data.get("plots") is Array or data.plots.size() > LandExpansionState.REGION.get_area():
		return false
	if data.prepared.size() > 15:
		return false
	var owners: Dictionary = {}
	var prepared_cells: Dictionary = {}
	for row: Variant in data.prepared:
		if not row is Dictionary or row.size() != 2 or not SaveSchema.identifier(row.get("worker")) or owners.has(row.worker) or not SaveSchema.vector(row.get("cell"), true):
			return false
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		if not LandExpansionState.REGION.has_point(cell) or prepared_cells.has(cell):
			return false
		owners[row.worker] = true
		prepared_cells[cell] = true
	var cells: Dictionary = {}
	for row: Variant in data.plots:
		if not row is Dictionary or row.size() != 4 or not SaveSchema.vector(row.get("cell"), true) or not SaveSchema.number(row.get("last"), 1, float(data.sequence), true) or not row.get("crop") is String or (not row.crop.is_empty() and not catalog.crops.has(row.crop)) or not SaveSchema.number(row.get("planted_at"), 0, saved_at):
			return false
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		if not LandExpansionState.REGION.has_point(cell) or cells.has(cell):
			return false
		cells[cell] = true
	return true
