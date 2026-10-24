class_name BeehiveProductionComponent
extends RefCounted
## One capped batch. Credit follows earned work, never the flower present at collection.
var definition: BeehiveDefinition
var work: float = 0.0
var contributions: Dictionary = {}
var ready_item: ItemDefinition
var legacy_batch: bool = false
var _collecting: bool = false

func advance(seconds: float, source: String) -> void:
	if ready_item != null or seconds <= 0.0:
		return
	var rate: float = definition.honey_rate(source, legacy_batch)
	var earned: float = minf(seconds * rate,definition.cycle_seconds - work)
	work += earned
	if not source.is_empty() and (legacy_batch or definition.is_specialty(source)):
		contributions[source] = float(contributions.get(source,0.0)) + earned
	if work >= definition.cycle_seconds - 0.000001:
		work = definition.cycle_seconds
		ready_item = expected_item()

func dominant_source() -> String:
	var best: String = ""
	var amount: float = 0.0
	for key: String in contributions:
		var value: float = float(contributions[key])
		if value > amount or (is_equal_approx(value,amount) and key < best):
			best = key
			amount = value
	return best if amount + 0.000001 >= definition.cycle_seconds * definition.specialty_ratio else ""

func expected_item() -> ItemDefinition:
	return definition.honey_for(dominant_source(), legacy_batch)

func batch_amount() -> int:
	return 1 if legacy_batch else definition.batch_amount

func collect(bag: InventoryComponent) -> ItemDefinition:
	if _collecting or ready_item == null or bag == null:
		return null
	var amount: int = batch_amount()
	if bag.capacity_for(ready_item) < amount:
		bag.report_capacity_blocked(ready_item,amount)
		return null
	_collecting = true
	var item: ItemDefinition = ready_item
	# Bag listeners see both a received jar and an already emptied hive.
	ready_item = null
	work = 0.0
	contributions = {}
	legacy_batch = false
	bag.add(item,amount)
	_collecting = false
	return item

func capture() -> Dictionary:
	return {"work":work,"contributions":contributions.duplicate(),"ready_item":String(ready_item.item_id) if ready_item != null else "", "legacy_batch": legacy_batch}
