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
@export_range(0, 32000) var stack_cap: int = 0

func stack_limit_for(item: ItemDefinition) -> int:
	return mini(item.get_stack_limit(), stack_cap) if stack_cap > 0 else item.get_stack_limit()
var _slots: Array[Dictionary] = []

func _ready() -> void:
	_ensure_slots()

func _ensure_slots() -> void:
	if not _slots.is_empty():
		return
	for index: int in range(maxi(1, slot_count)):
		_slots.append({"item": null, "count": 0, "tiers": [0, 0, 0]})
	if starting_tools:
		_slots[0] = {"item": HOE, "count": 1, "tiers": [1, 0, 0]}
		if _slots.size() > 1:
			_slots[1] = {"item": WATER, "count": 1, "tiers": [1, 0, 0]}

func slot(index: int) -> Dictionary:
	_ensure_slots()
	if index < 0 or index >= _slots.size():
		return {"item": null, "count": 0, "tiers": [0, 0, 0]}
	return _slots[index].duplicate(true)

func get_slot_item(index: int) -> ItemDefinition:
	_ensure_slots()
	return _slots[index].item if index >= 0 and index < _slots.size() else null

func get_slot_count(index: int) -> int:
	_ensure_slots()
	return int(_slots[index].count) if index >= 0 and index < _slots.size() else 0

func is_empty_slot(index: int) -> bool:
	return get_slot_item(index) == null

## One validated replacement, so UI never sees a half-restored inventory.
func replace_slots(stacks: Array[Dictionary], notify: bool = true) -> bool:
	if stacks.size() != slot_count:
		return false
	var replacement: Array[Dictionary] = []
	for stack: Dictionary in stacks:
		var item: ItemDefinition = stack.get("item") as ItemDefinition
		var amount: int = int(stack.get("count", 0))
		if (item == null and amount != 0) or (item != null and (amount < 1 or amount > stack_limit_for(item))):
			return false
		var tiers: Array = stack.get("tiers", [amount, 0, 0])
		if not ItemQuality.valid_tiers(tiers, item, amount):
			return false
		replacement.append({"item": item, "count": amount, "tiers": tiers.duplicate()})
	_slots = replacement
	if notify:
		changed.emit()
	return true

# Gộp vào stack cùng item trước, rồi mới lấp ô trống. Giá trị trả về là số THỰC NHẬN.
# Không được giả định luôn nhận đủ amount: caller nhặt đồ phải giữ phần dư trên đất,
# caller giao dịch/thu hoạch toàn bộ phải kiểm tra capacity trước khi thay đổi nguồn đồ.
# Nếu dùng amount thay vì kết quả trả về để xóa nguồn hoặc hiện +N, sẽ mất đồ/báo quá số nhận.
func add(item: ItemDefinition, amount: int = 1, tier: int = 0, notify: bool = true) -> int:
	_ensure_slots()
	if item == null or item.item_id.is_empty() or amount <= 0 or not ItemQuality.supported(item, tier):
		return 0
	var left: int = amount
	for stack: Dictionary in _slots:
		if stack.item != null and item.matches(stack.item):
			var moved: int = mini(left, stack_limit_for(item) - int(stack.count))
			stack.count += moved
			stack.tiers[tier] += moved
			left -= moved
	for stack: Dictionary in _slots:
		if left > 0 and stack.item == null:
			var moved: int = mini(left, stack_limit_for(item))
			stack.item = item
			stack.count = moved
			stack.tiers[tier] += moved
			left -= moved
	if left < amount and notify:
		changed.emit()
	return amount - left

## Consumption defaults to normal only. Transfers use transfer_slot_to instead.
func consume(item_id: StringName, amount: int, mode: Dictionary = {}, notify: bool = true) -> Array[int]:
	_ensure_slots()
	var removed: Array[int] = [0, 0, 0]
	if amount <= 0:
		return removed
	var tiers: Array[int] = ItemQuality.order(ItemQuality.exact() if mode.is_empty() else mode)
	var left: int = amount
	for tier: int in tiers:
		for stack: Dictionary in _slots:
			if stack.item == null or stack.item.item_id != item_id:
				continue
			var take: int = mini(left, int(stack.tiers[tier]))
			stack.tiers[tier] -= take
			stack.count -= take
			removed[tier] += take
			left -= take
			if stack.count == 0:
				stack.item = null
	if left < amount and notify:
		changed.emit()
	return removed

func remove(item_id: StringName, amount: int = 1, notify: bool = true) -> int:
	return consume(item_id, amount, ItemQuality.exact(), notify)[0]

func remove_from_slot(index: int, amount: int = 1, notify: bool = true, tier: int = 0) -> int:
	_ensure_slots()
	if index < 0 or index >= _slots.size() or amount <= 0 or tier < 0 or tier > 2:
		return 0
	var stack: Dictionary = _slots[index]
	var removed: int = mini(amount, int(stack.tiers[tier]))
	if removed > 0:
		stack.tiers[tier] -= removed
		stack.count -= removed
		if stack.count == 0:
			stack.item = null
		if notify:
			changed.emit()
	return removed

func transfer_slot_to(index: int, target: InventoryComponent, amount: int, notify: bool = true) -> int:
	if target == null or target == self or index < 0 or index >= slot_count or amount <= 0:
		return 0
	var source: Dictionary = slot(index)
	var item: ItemDefinition = source.item
	if item == null:
		return 0
	var left: int = mini(amount, target.capacity_for(item))
	var total: int = 0
	for tier: int in range(3):
		var moved: int = mini(left, int(source.tiers[tier]))
		if moved > 0:
			remove_from_slot(index, moved, false, tier)
			target.add(item, moved, tier, false)
			total += moved
			left -= moved
	if total > 0 and notify:
		changed.emit()
		target.changed.emit()
	return total

func count(item_id: StringName, tier: int = 0) -> int:
	return count_item(item_id, tier)

func has(item_id: StringName, amount: int, tier: int = 0) -> bool:
	return amount >= 0 and count_item(item_id, tier) >= amount

# Sức chứa tính theo từng loại: tổng chỗ còn trong stack cùng item + sức chứa các ô rỗng.
# Túi kín vẫn có thể nhận trứng nếu stack trứng chưa đầy, nhưng không nhận sữa chưa có stack.
# Không thể chỉ đếm ô trống hoặc chỉ nhìn tổng số lượng. Đây là lý do các loại vật phẩm
# có vẻ nhặt khác nhau dù dùng cùng thuật toán; số 64 ô là cấu hình có thể đổi, quy tắc gộp phải đúng.
func capacity_for(item: ItemDefinition) -> int:
	_ensure_slots()
	if item == null:
		return 0
	var available: int = 0
	for stack: Dictionary in _slots:
		if stack.item == null:
			available += stack_limit_for(item)
		elif item.matches(stack.item):
			available += maxi(0, stack_limit_for(item) - int(stack.count))
	return available

func report_capacity_blocked(item: ItemDefinition, requested: int) -> void:
	if item == null or requested <= 0:
		return
	var available: int = capacity_for(item)
	if available < requested:
		capacity_blocked.emit(item, requested, available)

func count_item(item_id: StringName, tier: int = 0) -> int:
	_ensure_slots()
	var count: int = 0
	for stack: Dictionary in _slots:
		if stack.item != null and stack.item.item_id == item_id:
			count += int(stack.count) if tier == -1 else int(stack.tiers[tier]) if tier >= 0 and tier < 3 else 0
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
		var moved: int = mini(int(from.count), stack_limit_for(item) - int(to.count))
		if moved <= 0:
			return false
		var left: int = moved
		for tier: int in range(3):
			var take: int = mini(left, int(from.tiers[tier]))
			to.tiers[tier] += take
			from.tiers[tier] -= take
			left -= take
		to.count += moved
		from.count -= moved
		if from.count == 0:
			from.item = null
	else:
		_slots[source] = to
		_slots[target] = from
	changed.emit()
	return true
