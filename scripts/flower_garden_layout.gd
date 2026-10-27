extends RefCounted
## Four equal 7x4 blocks, fitted to the existing 160x96 soil beds.
const COLUMNS: int = 14
const ROWS: int = 8
const CAPACITY: int = COLUMNS * ROWS
const SPACING: int = 22
const ROW_SPACING: int = 14
const SAVE_COLUMNS: int = 18
const SAVE_ROWS: int = 10
const SAVE_CAPACITY: int = SAVE_COLUMNS * SAVE_ROWS

static func position_for(cell: Vector2i) -> Vector2:
	# Visible flower bounds are y=-41..-1 from the pot's ground anchor.
	# Four rows now occupy 82px, leaving 7px above and below inside each 96px bed.
	return Vector2(30 + (cell.x % 7) * SPACING + (192 if cell.x >= 7 else 0), 64 + (cell.y % 4) * ROW_SPACING + (128 if cell.y >= 4 else 0))

static func soil_bounds_for(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(16 + (192 if cell.x >= 7 else 0), 16 + (128 if cell.y >= 4 else 0)), Vector2(160, 96))

static func from_legacy(cell: Vector2i) -> Vector2i:
	# Keep historical save coordinates; surplus plants are queued by FlowerGarden.
	return Vector2i(cell.x * 2 - (1 if cell.x >= 5 else 0), cell.y * 2 - (1 if cell.y >= 3 else 0))
