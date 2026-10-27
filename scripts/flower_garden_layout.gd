extends RefCounted
## Four authored 5x4 blocks. Retain historical cell IDs for existing saves.
const COLUMNS: int = 14
const ROWS: int = 8
const BLOCK_COLUMNS: int = 5
const CAPACITY: int = BLOCK_COLUMNS * 4 * 4
const SPACING: int = 32
const ROW_SPACING: int = 22
const ROW_POSITIONS: Array[int] = [40, 62, 83, 106]
const SAVE_COLUMNS: int = 18
const SAVE_ROWS: int = 10
const SAVE_CAPACITY: int = SAVE_COLUMNS * SAVE_ROWS

static func position_for(cell: Vector2i) -> Vector2:
	return Vector2(32 + (cell.x % 7) * SPACING + (192 if cell.x >= 7 else 0), ROW_POSITIONS[cell.y % 4] + (128 if cell.y >= 4 else 0))

static func contains_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS and cell.x % 7 < BLOCK_COLUMNS

static func soil_bounds_for(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(16 + (192 if cell.x >= 7 else 0), 16 + (128 if cell.y >= 4 else 0)), Vector2(160, 96))

static func from_legacy(cell: Vector2i) -> Vector2i:
	# Keep historical save coordinates; surplus plants are queued by FlowerGarden.
	return Vector2i(cell.x * 2 - (1 if cell.x >= 5 else 0), cell.y * 2 - (1 if cell.y >= 3 else 0))
