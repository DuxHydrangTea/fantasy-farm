class_name InventoryComponent
extends Node

# Fixed-slot inventory adapted from the Godot skill's inventory.gd template.
signal changed
signal capacity_blocked(item: ItemDefinition, requested: int, available: int)
const DEFAULT_SLOT_COUNT: int = 64
const LEGACY_SLOT_COUNT: int = 24

const HOE: Resource = preload("res://items/tools/hoe.tres")
const WATER: Resource = preload("res://items/tools/watering_can.tres")

@export var slot_count: int = DEFAULT_SLOT_COUNT
@export var starting_tools: bool = true
var _slots: Array[Dictionary] = []

func _ready() -> void:
	_ensure_slots()

func _ensure_slots() -> void:
	if not _slots.is_empty():
		return
	for index: int in range(maxi(1, slot_count)):
		_slots.append({"item": null, "count": 0})
	if starting_tools:
		_slots[0] = {"item": HOE, "count": 1}
		if _slots.size() > 1:
			_slots[1] = {"item": WATER, "count": 1}

func slot(index: int) -> Dictionary:
	_ensure_slots()
	if index < 0 or index >= _slots.size():
		return {"item": null, "count": 0}
	return _slots[index].duplicate()

func get_slot_item(index: int) -> ItemDefinition:
	_ensure_slots()
	return _slots[index].item if index >= 0 and index < _slots.size() else null

func get_slot_count(index: int) -> int:
	_ensure_slots()
	return int(_slots[index].count) if index >= 0 and index < _slots.size() else 0

func is_empty_slot(index: int) -> bool:
	return get_slot_item(index) == null

## One validated replacement, so UI never sees a half-restored inventory.
func replace_slots(stacks: Array[Dictionary]) -> bool:
	if stacks.size() != slot_count:
		return false
	var replacement: Array[Dictionary] = []
	for stack: Dictionary in stacks:
		var item: ItemDefinition = stack.get("item") as ItemDefinition
		var amount: int = int(stack.get("count", 0))
		if (item == null and amount != 0) or (item != null and (amount < 1 or amount > item.get_stack_limit())):
			return false
		replacement.append({"item": item, "count": amount})
	_slots = replacement
	changed.emit()
	return true

func add(item: ItemDefinition, amount: int = 1) -> int:
	_ensure_slots()
	if item == null or item.item_id.is_empty() or amount <= 0:
		return 0
	var left: int = amount
	for stack: Dictionary in _slots:
		if stack.item != null and item.matches(stack.item):
			var moved: int = mini(left, item.get_stack_limit() - int(stack.count))
			stack.count += moved
			left -= moved
	for stack: Dictionary in _slots:
		if left > 0 and stack.item == null:
			var moved: int = mini(left, item.get_stack_limit())
			stack.item = item
			stack.count = moved
			left -= moved
	if left < amount:
		changed.emit()
	return amount - left

func remove(item_id: StringName, amount: int = 1) -> int:
	_ensure_slots()
	if amount <= 0:
		return 0
	var left: int = amount
	for stack: Dictionary in _slots:
		if stack.item != null and stack.item.item_id == item_id:
			var removed: int = mini(left, int(stack.count))
			stack.count -= removed
			left -= removed
			if stack.count == 0:
				stack.item = null
	if left < amount:
		changed.emit()
	return amount - left

func remove_from_slot(index: int, amount: int = 1) -> int:
	_ensure_slots()
	if index < 0 or index >= _slots.size() or amount <= 0:
		return 0
	var stack: Dictionary = _slots[index]
	var removed: int = mini(amount, int(stack.count))
	if removed > 0:
		stack.count -= removed
		if stack.count == 0:
			stack.item = null
		changed.emit()
	return removed

func capacity_for(item: ItemDefinition) -> int:
	_ensure_slots()
	if item == null:
		return 0
	var available: int = 0
	for stack: Dictionary in _slots:
		if stack.item == null:
			available += item.get_stack_limit()
		elif item.matches(stack.item):
			available += maxi(0, item.get_stack_limit() - int(stack.count))
	return available

func report_capacity_blocked(item: ItemDefinition, requested: int) -> void:
	if item == null or requested <= 0:
		return
	var available: int = capacity_for(item)
	if available < requested:
		capacity_blocked.emit(item, requested, available)

func count_item(item_id: StringName) -> int:
	_ensure_slots()
	var count: int = 0
	for stack: Dictionary in _slots:
		if stack.item != null and stack.item.item_id == item_id:
			count += int(stack.count)
	return count

func move_slot(source: int, target: int) -> bool:
	_ensure_slots()
	if source == target or source < 0 or target < 0 or source >= _slots.size() or target >= _slots.size():
		return false
	var from: Dictionary = _slots[source]
	var to: Dictionary = _slots[target]
	var item: ItemDefinition = from.item
	if item == null:
		return false
	if to.item != null and item.matches(to.item):
		var moved: int = mini(int(from.count), item.get_stack_limit() - int(to.count))
		if moved <= 0:
			return false
		to.count += moved
		from.count -= moved
		if from.count == 0:
			from.item = null
	else:
		_slots[source] = to
		_slots[target] = from
	changed.emit()
	return true
