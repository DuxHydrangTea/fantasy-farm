@tool
class_name GrowthSchedule
extends RefCounted
## Min-heap of stage deadlines. Weak references never keep harvested plants alive.
# TỐI ƯU LỊCH LỚN CÂY — min-heap là một lựa chọn, không phải điều kiện để cây lớn đúng.
# Điều bắt buộc là xử lý đúng deadline; có thể thay heap bằng hàng đợi khác nếu vẫn giữ
# ngữ nghĩa đó. Heap đặt deadline nhỏ nhất ở phần tử 0: chỉ nhìn đầu là biết có việc đến hạn.
# Thêm/lấy một lịch tốn O(log n), thay vì duyệt mọi cây ở mỗi tick của đồng hồ.
# Nếu bỏ lịch và tính lại toàn bộ hàng nghìn cây mỗi tick, kết quả vẫn có thể đúng nhưng tốn CPU.
# Với cây đã chín không còn mốc chuyển stage, không cần tiếp tục đưa vào lịch.
var _heap: Array[Dictionary] = []
var _tickets: Dictionary[int, int] = {}
var _sequence: int = 0

# Mỗi lần đặt lịch cấp một ticket tăng dần, kể cả khi cùng một Node được đặt lịch lại.
# Heap có thể còn dòng cũ, nhưng ticket giúp nhận ra dòng nào đã hết hiệu lực.
# WeakRef chỉ giữ liên kết yếu: cây đã thu hoạch/free không bị lịch giữ tham chiếu sử dụng lại.
# Nếu bỏ ticket, một lịch cũ có thể làm cây cập nhật sớm; nếu dùng Node đã free trực tiếp
# mà không kiểm tra, lúc đến hạn có thể gọi phương thức lên đối tượng không còn tồn tại.
func schedule(target: Node, deadline: float) -> void:
	_sequence += 1
	_tickets[target.get_instance_id()] = _sequence
	var row: Dictionary = {"at": deadline, "ref": weakref(target), "id": target.get_instance_id(), "ticket": _sequence}
	_heap.append(row)
	var index: int = _heap.size() - 1
	# Biểu diễn cây nhị phân bằng mảng: cha của ô i là floor((i - 1) / 2), hai con là 2i+1, 2i+2.
	# Đẩy deadline mới lên đến khi cha không lớn hơn nó; nhờ vậy ô 0 luôn là lịch gần nhất.
	# Nếu chỉ append mà không sửa thứ tự, một lịch sớm nằm cuối mảng có thể bị xử lý trễ.
	while index > 0:
		var parent: int = (index - 1) / 2
		if _heap[parent].at <= row.at:
			break
		_heap[index] = _heap[parent]
		index = parent
	_heap[index] = row

# Hủy bằng cách xóa ticket, không tìm/xóa giữa heap (tìm như vậy tốn O(n)).
# Dòng cũ sẽ bị bỏ qua khi trồi lên đầu; đổi lại nó còn chiếm chỗ đến khi được lấy ra/clear.
# Không được bỏ kiểm tra ticket trong take_due chỉ vì cancel không trực tiếp xóa phần tử heap.
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
			# Sau khi lấy gốc, đưa phần tử cuối xuống nhánh con có deadline nhỏ hơn.
			# Đây là bước khôi phục tính chất min-heap; chọn nhầm con có thể làm lịch đến hạn nằm dưới
			# một lịch tương lai và vòng while bên ngoài tưởng rằng chưa cần xử lý gì.
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
