class_name AnimalProductionComponent
extends Node
## Pure production state. The actor hands eligible time in and delivers output.
signal produced(amount: int)
signal stock_changed(amount: int)
var definition: AnimalProductionDefinition
var progress_seconds: float = 0.0
var stored_amount: int = 0
var _collecting: bool = false

func configure(data: AnimalProductionDefinition) -> void:
	definition = data
	progress_seconds = 0.0
	stored_amount = 0

func progress_ratio() -> float:
	return progress_seconds / definition.production_seconds if definition != null and definition.is_valid() else 0.0

func restore_state(progress: float, amount: int) -> void:
	progress_seconds = progress
	stored_amount = amount
	stock_changed.emit(stored_amount)

func advance(eligible_seconds: float) -> int:
	if eligible_seconds <= 0.0 or definition == null or not definition.is_valid():
		return 0
	progress_seconds += eligible_seconds
	var batches: int = floori((progress_seconds + 0.000001) / definition.production_seconds)
	if batches <= 0:
		return 0
	progress_seconds = maxf(0.0, progress_seconds - batches * definition.production_seconds)
	var amount: int = batches * definition.production_amount
	stored_amount += amount
	stock_changed.emit(stored_amount)
	produced.emit(amount)
	return amount

func take_output(amount: int) -> int:
	var removed: int = mini(maxi(0, amount), stored_amount)
	if removed > 0:
		stored_amount -= removed
		stock_changed.emit(stored_amount)
	return removed

## Used by DIRECT_COLLECTION definitions; partial transfers preserve the rest.
func collect(inventory: InventoryComponent) -> int:
	if _collecting or inventory == null or definition == null or not definition.is_valid() or stored_amount <= 0:
		return 0
	_collecting = true
	var accepted: int = inventory.add(definition.production_item, stored_amount)
	take_output(accepted)
	_collecting = false
	return accepted
