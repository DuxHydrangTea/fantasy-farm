class_name LandExpansionState
extends RefCounted
## Contiguous ownership from right to left in the measured planting rectangle.
signal changed
const REGION: Rect2i = Rect2i(9, 19, 48, 34)
const BASE_PRICE: int = 60000
const STARTING_COLUMNS: int = 4
var starting_columns: int = STARTING_COLUMNS
var unlocked_columns: int = STARTING_COLUMNS
var _buying: bool = false

static func cell_is_open(cell: Vector2i, columns: int) -> bool:
	return not REGION.has_point(cell) or cell.x >= REGION.end.x - columns

func is_unlocked(cell: Vector2i) -> bool:
	return cell_is_open(cell, unlocked_columns)

func is_complete() -> bool:
	return unlocked_columns == REGION.size.x

func next_column() -> int:
	return REGION.end.x - unlocked_columns - 1

func next_price() -> int:
	if is_complete():
		return 0
	var purchase_number: int = unlocked_columns - starting_columns + 1
	if purchase_number == 2:
		return 150000
	if purchase_number == 3:
		return 350000
	return roundi(350000.0 * pow(float(purchase_number) / 3.0, 1.8)) if purchase_number > 3 else BASE_PRICE

func restore_columns(columns: int, initial_columns: int = 1) -> bool:
	if _buying or initial_columns < 1 or initial_columns > columns or columns > REGION.size.x:
		return false
	starting_columns = initial_columns
	unlocked_columns = columns
	changed.emit()
	return true

func purchase(wallet: WalletComponent, expected_columns: int) -> Dictionary:
	if _buying:
		return {"ok": false, "error": "A land purchase is in progress."}
	if is_complete():
		return {"ok": false, "error": "All farmland is already unlocked."}
	if expected_columns != unlocked_columns:
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
	unlocked_columns += 1
	wallet.changed.emit(wallet.balance)
	changed.emit()
	_buying = false
	return {"ok": true, "price": price, "column": REGION.end.x - unlocked_columns}
