class_name LandExpansionState
extends RefCounted
## Buy one path-bounded block at a time, snaking down/up from the top right.
signal changed
const LEGACY_REGION: Rect2i = Rect2i(9, 19, 48, 34)
const REGION: Rect2i = Rect2i(4, 19, 53, 35)
const BLOCK_SIZE: int = 8
const BASE_PRICE: int = 60000
const BLOCK_COUNT: int = 24
const STARTING_BLOCKS: int = 1
const LEGACY_X_STARTS: Array[int] = [9, 17, 25, 33, 41, 49]
const LEGACY_X_ENDS: Array[int] = [16, 24, 32, 40, 48, 57]
const LEGACY_Y_STARTS: Array[int] = [19, 28, 37, 45]
const LEGACY_Y_ENDS: Array[int] = [27, 36, 44, 53]
var starting_blocks: int = STARTING_BLOCKS
var unlocked_blocks: int = STARTING_BLOCKS
var _buying: bool = false

static func block_rect(index: int) -> Rect2i:
	if index < 0 or index >= BLOCK_COUNT:
		return Rect2i()
	var column_offset: int = floori(float(index) / 4.0)
	var column: int = 5 - column_offset
	var row: int = index % 4 if column_offset % 2 == 0 else 3 - index % 4
	var origin: Vector2i = REGION.position + Vector2i(column, row) * (BLOCK_SIZE + 1)
	return Rect2i(origin, Vector2i(BLOCK_SIZE, BLOCK_SIZE))

static func from_legacy_cell(cell: Vector2i) -> Vector2i:
	if not LEGACY_REGION.has_point(cell):
		return cell
	return Vector2i(
		_expand_legacy_axis(cell.x, REGION.position.x, LEGACY_X_STARTS, LEGACY_X_ENDS),
		_expand_legacy_axis(cell.y, REGION.position.y, LEGACY_Y_STARTS, LEGACY_Y_ENDS)
	)

static func _expand_legacy_axis(value: int, origin: int, starts: Array[int], ends: Array[int]) -> int:
	for index: int in range(starts.size()):
		var start: int = origin + index * (BLOCK_SIZE + 1)
		if value < ends[index]:
			return start + value - starts[index]
		if value == ends[index]:
			return start + BLOCK_SIZE
	return value

static func block_index(cell: Vector2i) -> int:
	for index: int in range(BLOCK_COUNT):
		if block_rect(index).has_point(cell):
			return index
	return -1

static func legacy_block_count(columns: int) -> int:
	for column: int in range(LEGACY_X_ENDS.size()):
		if LEGACY_X_ENDS[column] > LEGACY_REGION.end.x - columns:
			return (LEGACY_X_ENDS.size() - column) * LEGACY_Y_STARTS.size()
	return 1

static func cell_is_open(cell: Vector2i, blocks: int) -> bool:
	# Paths remain walkable and visible; their TileData separately blocks farming.
	var index: int = block_index(cell)
	return index < 0 or index < blocks

func is_unlocked(cell: Vector2i) -> bool:
	return cell_is_open(cell, unlocked_blocks)

func is_complete() -> bool:
	return unlocked_blocks == BLOCK_COUNT

func next_block() -> Rect2i:
	return block_rect(unlocked_blocks)

func next_price() -> int:
	if is_complete():
		return 0
	var purchase_number: int = unlocked_blocks - starting_blocks + 1
	if purchase_number == 2:
		return 150000
	if purchase_number == 3:
		return 350000
	return roundi(350000.0 * pow(float(purchase_number) / 3.0, 1.8)) if purchase_number > 3 else BASE_PRICE

func restore_blocks(blocks: int, initial_blocks: int = 1) -> bool:
	if _buying or initial_blocks < 1 or initial_blocks > blocks or blocks > BLOCK_COUNT:
		return false
	starting_blocks = initial_blocks
	unlocked_blocks = blocks
	changed.emit()
	return true

func purchase(wallet: WalletComponent, expected_blocks: int) -> Dictionary:
	if _buying:
		return {"ok": false, "error": "A land purchase is in progress."}
	if is_complete():
		return {"ok": false, "error": "All farmland is already unlocked."}
	if expected_blocks != unlocked_blocks:
		return {"ok": false, "error": "The land offer changed. Please try again."}
	if not is_instance_valid(wallet):
		return {"ok": false, "error": "Land purchasing is unavailable."}
	var price: int = next_price()
	if wallet.balance < price:
		return {"ok": false, "error": "Not enough coins."}
	_buying = true
	# Commit both models before notifying. Signal listeners cannot buy recursively
	# or see the wallet debited while ownership still has its previous value.
	wallet.set_balance(wallet.balance - price, false)
	unlocked_blocks += 1
	wallet.changed.emit(wallet.balance)
	changed.emit()
	_buying = false
	return {"ok": true, "price": price, "block": unlocked_blocks - 1}
