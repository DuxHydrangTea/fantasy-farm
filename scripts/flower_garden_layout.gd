extends RefCounted
## Dense beds share one layout contract with save validation and migration.
const COLUMNS: int = 18
const ROWS: int = 10
const CAPACITY: int = COLUMNS * ROWS
const SPACING: int = 16

static func position_for(cell: Vector2i) -> Vector2:
	return Vector2(32 + cell.x * SPACING + (48 if cell.x >= 9 else 0), 32 + cell.y * SPACING + (48 if cell.y >= 5 else 0))

static func from_legacy(cell: Vector2i) -> Vector2i:
	# Old pots remain at exactly the same world positions; new pots fill gaps.
	return Vector2i(cell.x * 2 - (1 if cell.x >= 5 else 0), cell.y * 2 - (1 if cell.y >= 3 else 0))
