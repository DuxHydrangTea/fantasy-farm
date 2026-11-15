class_name CropAutomationState
extends RefCounted
## Cấu hình tự động trồng và lịch sử ô của công nhân, được lưu dưới dạng dữ liệu cơ bản.
## Ô đã chuẩn bị được gắn với công nhân để tiếp tục giữa các bước làm đất và gieo.

## Revision dùng phát hiện công việc được lập theo cấu hình cũ.
var revision: int = 0
## Bật tự động làm đất và gieo.
var auto_plant: bool = false
## Bật tự động bón phân.
var auto_fertilize: bool = false
## Tạm dừng tự động hóa.
var paused: bool = false
## Chờ chăm sóc cây bị ảnh hưởng trước khi thu.
var wait_for_care: bool = true
## Chế độ ưu tiên công việc.
var priority_mode: String = "balanced"
## Các ô đã chuẩn bị theo mã công nhân.
var prepared: Dictionary = {}
## Số thứ tự tăng khi ghi nhận lần trồng.
var sequence: int = 0
## Lịch sử ô theo tọa độ, gồm thứ tự gần nhất, mã cây và thời điểm gieo.
var plots: Dictionary[Vector2i, Dictionary] = {}

## Tạo dữ liệu mặc định chưa bật tự động hóa.
static func fresh() -> Dictionary:
	return {"revision": 0, "auto_plant": false, "auto_fertilize": false, "paused": false, "wait_for_care": true, "prepared": [], "sequence": 0, "plots": []}

## Chuyển trạng thái sang cấu trúc lưu ổn định, sắp xếp công nhân và ô.
func capture() -> Dictionary:
	var data: Dictionary = fresh()
	data.revision = revision
	data.auto_plant = auto_plant
	data.auto_fertilize = auto_fertilize
	data.paused = paused
	data.wait_for_care = wait_for_care
	data["priority_mode"] = priority_mode
	var ids: Array[String] = []
	ids.assign(prepared.keys())
	ids.sort()
	for id: String in ids:
		var pairs: Array = []
		for cell: Vector2i in prepared_cells(id):
			pairs.append([cell.x, cell.y])
		if not pairs.is_empty():
			data.prepared.append({"worker": id, "cell": pairs[0], "cells": pairs})
	data.sequence = sequence
	var cells: Array[Vector2i] = plots.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var row: Dictionary = plots[cell]
		data.plots.append({"cell": [cell.x, cell.y], "last": int(row.last), "crop": String(row.crop), "planted_at": float(row.planted_at)})
	return data

## Khôi phục dữ liệu đã kiểm tra, hỗ trợ bản ghi cũ có một ô chuẩn bị.
func restore(data: Dictionary) -> void:
	revision = int(data.revision)
	auto_plant = data.auto_plant
	auto_fertilize = data.auto_fertilize
	paused = data.paused
	wait_for_care = data.wait_for_care
	priority_mode = String(data.get("priority_mode", "balanced"))
	sequence = int(data.sequence)
	prepared.clear()
	for row: Dictionary in data.prepared:
		var cells: Array[Vector2i] = []
		for cell: Array in row.get("cells", [row.cell]):
			cells.append(Vector2i(int(cell[0]), int(cell[1])))
		prepared[row.worker] = cells
	plots.clear()
	for row: Dictionary in data.plots:
		plots[Vector2i(int(row.cell[0]), int(row.cell[1]))] = {"last": int(row.last), "crop": String(row.crop), "planted_at": float(row.planted_at)}

## Ghi cây vừa trồng vào lịch sử và bỏ ô khỏi danh sách chuẩn bị.
func remember(cell: Vector2i, crop: Crop) -> void:
	sequence += 1
	plots[cell] = {"last": sequence, "crop": String(crop.definition.crop_id), "planted_at": crop.planted_at}
	clear_prepared(cell)

## Xóa thông tin cây hiện tại của ô và bỏ giữ ô chuẩn bị.
func forget_crop(cell: Vector2i) -> void:
	if plots.has(cell):
		plots[cell].crop = ""
		plots[cell].planted_at = 0.0
	clear_prepared(cell)

## Kiểm tra cây còn khớp mã và thời điểm trồng đã ghi tại ô.
func owns(cell: Vector2i, crop: Crop) -> bool:
	return crop != null and plots.has(cell) and String(plots[cell].crop) == String(crop.definition.crop_id) and float(plots[cell].planted_at) == crop.planted_at

## Trả danh sách ô đã chuẩn bị cho công nhân, hỗ trợ biểu diễn cũ một Vector2i.
func prepared_cells(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var value: Variant = prepared.get(id)
	if value is Vector2i:
		result.append(value)
	elif value is Array:
		result.assign(value)
	return result

## Trả ô chuẩn bị đầu tiên, hoặc (-1, -1) nếu không có.
func prepared_for(id: String) -> Vector2i:
	var cells: Array[Vector2i] = prepared_cells(id)
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)

## Ghi ô chuẩn bị cho công nhân nếu chưa có trong danh sách.
func add_prepared(id: String, cell: Vector2i) -> void:
	var cells: Array[Vector2i] = prepared_cells(id)
	if not cells.has(cell):
		cells.append(cell)
	prepared[id] = cells

## Bỏ ô chuẩn bị khỏi mọi công nhân.
func clear_prepared(cell: Vector2i) -> void:
	for id: String in prepared.keys():
		remove_prepared(id, cell)

## Bỏ một ô khỏi danh sách của công nhân và xóa danh sách nếu rỗng.
func remove_prepared(id: String, cell: Vector2i) -> void:
	var cells: Array[Vector2i] = prepared_cells(id)
	cells.erase(cell)
	if cells.is_empty():
		prepared.erase(id)
	else:
		prepared[id] = cells

## Kiểm tra cấu hình, revision, lịch sử và ô chuẩn bị trong dữ liệu lưu.
## Ô chuẩn bị không được trùng; mã cây và thời điểm phải hợp lệ theo catalog.
static func valid(data: Variant, catalog: SaveCatalog, saved_at: float) -> bool:
	if not data is Dictionary or data.size() not in [8, 9] or not data.get("priority_mode", "balanced") in ["balanced", "care_first", "harvest_first"] or not data.get("wait_for_care") is bool or not SaveSchema.number(data.get("revision"), 0, 1.0e12, true) or not data.get("auto_plant") is bool or not data.get("auto_fertilize") is bool or not data.get("paused") is bool or not SaveSchema.number(data.get("sequence"), 0, 1.0e12, true) or not data.get("prepared") is Array or not data.get("plots") is Array or data.plots.size() > LandExpansionState.REGION.get_area():
		return false
	if data.prepared.size() > 15:
		return false
	if data.size() == 9 and not data.has("priority_mode"):
		return false
	var owners: Dictionary = {}
	var prepared_targets: Dictionary = {}
	for row: Variant in data.prepared:
		if not row is Dictionary or row.size() not in [2, 3] or not SaveSchema.identifier(row.get("worker")) or owners.has(row.worker) or not SaveSchema.vector(row.get("cell"), true):
			return false
		var batch: Variant = row.get("cells", [row.cell])
		if not batch is Array or batch.is_empty() or batch.size() > 9 or batch[0] != row.cell:
			return false
		for pair: Variant in batch:
			if not SaveSchema.vector(pair, true):
				return false
			var cell: Vector2i = Vector2i(int(pair[0]), int(pair[1]))
			if not LandExpansionState.REGION.has_point(cell) or prepared_targets.has(cell):
				return false
			prepared_targets[cell] = true
		owners[row.worker] = true
	var cells: Dictionary = {}
	for row: Variant in data.plots:
		if not row is Dictionary or row.size() != 4 or not SaveSchema.vector(row.get("cell"), true) or not SaveSchema.number(row.get("last"), 1, float(data.sequence), true) or not row.get("crop") is String or (not row.crop.is_empty() and not catalog.crops.has(row.crop)) or not SaveSchema.number(row.get("planted_at"), 0, saved_at):
			return false
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		if not LandExpansionState.REGION.has_point(cell) or cells.has(cell):
			return false
		cells[cell] = true
	return true
