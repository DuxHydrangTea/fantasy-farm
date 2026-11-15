class_name TreePlotUpgradeState
extends RefCounted
## Lưu cấp mở rộng riêng cho khu cây ăn quả và cây lấy gỗ.
## Cấp quyết định số cột được dùng và sức chứa, mỗi cấp thêm chín ô.

## Signal do nơi điều phối phát khi cấp của một loại thay đổi.
signal changed(kind: TreeDefinition.Kind)
## Danh mục giá mở rộng.
const CATALOG: TreePlotUpgradeCatalog = preload("res://resources/trees/plot_upgrades.tres")
## Cấp mở rộng tối đa.
const MAX_LEVEL: int = 17
## Số ô được mở ở mỗi cấp.
const SLOTS_PER_LEVEL: int = 9
var _levels: Dictionary = fresh()
var _busy: bool = false

## Tạo trạng thái mới với hai khu đều ở cấp 1.
static func fresh() -> Dictionary:
	var result: Dictionary = {}
	for id: String in ["fruit", "timber"]:
		result[id] = 1
	return result

## Kiểm tra đủ hai khóa và cấp nguyên từ 1 đến cấp tối đa.
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != ["fruit", "timber"].size():
		return false
	for id: String in ["fruit", "timber"]:
		var value: Variant = data.get(id)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 1 or value > MAX_LEVEL or float(value) != floor(float(value)):
			return false
	return true

## Chuyển loại cây thành khóa lưu fruit hoặc timber.
static func key(kind: TreeDefinition.Kind) -> String:
	return "fruit" if kind == TreeDefinition.Kind.FRUIT else "timber"

## Tính chỉ số cột mở rộng của ô theo vùng trồng loại cây tương ứng.
static func column(cell: Vector2i, kind: TreeDefinition.Kind) -> int:
	return floori(float(cell.x - TreePlantation.region_for(kind).position.x - 2) / 3.0)

## Kiểm tra ô hợp lệ trong vùng trồng và thuộc cột đã mở theo dữ liệu cấp.
static func allows(data: Dictionary, cell: Vector2i, kind: TreeDefinition.Kind) -> bool:
	return TreePlantation.valid_cell(cell, kind) and column(cell, kind) < int(data.get(key(kind), 0))

## Suy ra cấp tối thiểu cần mở để chứa các cây trong dữ liệu lưu cũ.
## Trả dictionary rỗng nếu mã cây hoặc tọa độ trong dữ liệu không hợp lệ.
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

## Lấy cấp hiện tại của khu trồng.
func level(kind: TreeDefinition.Kind) -> int:
	return int(_levels.get(key(kind), 0))

## Tính số ô được mở từ cấp hiện tại.
func capacity(kind: TreeDefinition.Kind) -> int:
	return level(kind) * SLOTS_PER_LEVEL

## Tạo bản sao sâu của cấp hai khu để lưu.
func capture() -> Dictionary:
	return _levels.duplicate(true)

## Khôi phục dữ liệu hợp lệ khi không có giao dịch nâng cấp đang chạy.
func restore(data: Dictionary) -> bool:
	if _busy or not valid(data):
		return false
	_levels = data.duplicate(true)
	return true

## Cho biết giao dịch nâng cấp đang được xử lý.
func is_busy() -> bool:
	return _busy

## Khóa trạng thái để bắt đầu giao dịch nếu chưa có giao dịch khác.
func begin_purchase() -> bool:
	if _busy:
		return false
	_busy = true
	return true

## Tăng một cấp nếu giao dịch đang mở và cấp hiện tại khớp cấp dự kiến.
func commit(kind: TreeDefinition.Kind, expected_level: int) -> bool:
	if not _busy or level(kind) != expected_level or expected_level < 1 or expected_level >= MAX_LEVEL:
		return false
	_levels[key(kind)] = expected_level + 1
	return true

## Kết thúc khóa giao dịch.
func end_purchase() -> void:
	_busy = false
