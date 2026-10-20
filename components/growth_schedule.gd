@tool
class_name GrowthSchedule
extends RefCounted
## Min-heap of stage deadlines. Weak references never keep harvested plants alive.
var _heap: Array[Dictionary] = []
var _tickets: Dictionary[int, int] = {}
var _sequence: int = 0

func schedule(target: Node, deadline: float) -> void:
	_sequence += 1
	_tickets[target.get_instance_id()] = _sequence
	var row: Dictionary = {"at": deadline, "ref": weakref(target), "id": target.get_instance_id(), "ticket": _sequence}
	_heap.append(row)
	var index: int = _heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if _heap[parent].at <= row.at:
			break
		_heap[index] = _heap[parent]
		index = parent
	_heap[index] = row

func cancel(target: Node) -> void:
	_tickets.erase(target.get_instance_id())

func clear() -> void:
	_heap.clear()
	_tickets.clear()

func take_due(now: float) -> Array[Node]:
	var result: Array[Node] = []
	while not _heap.is_empty() and float(_heap[0].at) <= now:
		var row: Dictionary = _heap[0]
		var last: Dictionary = _heap.pop_back()
		if not _heap.is_empty():
			var index: int = 0
			while index * 2 + 1 < _heap.size():
				var child: int = index * 2 + 1
				if child + 1 < _heap.size() and _heap[child + 1].at < _heap[child].at:
					child += 1
				if last.at <= _heap[child].at:
					break
				_heap[index] = _heap[child]
				index = child
			_heap[index] = last
		if _tickets.get(row.id) != row.ticket:
			continue
		_tickets.erase(row.id)
		var target: Node = row.ref.get_ref() as Node
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			result.append(target)
	return result
