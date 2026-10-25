class_name FertileSoil
extends RefCounted
## Version 1 is frozen. Future layouts need a new branch and deliberate migration.
const CURRENT_VERSION: int = 1
var layout_version: int = CURRENT_VERSION

static func valid_version(value: Variant) -> bool:
	return (value is int or value is float) and value == 1

func is_fertile(cell: Vector2i) -> bool:
	if not LandExpansionState.REGION.has_point(cell):
		return false
	match layout_version:
		1:
			var value: int = (cell.x * 73856093 ^ cell.y * 19349663 ^ 83492791) & 0x7fffffff
			value = ((value ^ (value >> 13)) * 1103515245 + 12345) & 0x7fffffff
			return value % 100 < 18
	return false

func amount(cell: Vector2i, base: int) -> int:
	return maxi(base+1,roundi(base*1.5)) if is_fertile(cell) else base
