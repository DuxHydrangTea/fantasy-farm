class_name AnimalForagingComponent
extends Node
## Chọn máng, giữ chỗ, đi tới và nhận thức ăn hoặc nước cho vật nuôi.
## Behaviour quản lý trạng thái và hoạt ảnh; Needs quản lý các chỉ số no, nước.

## Phát khi đã nhận được khẩu phần, kèm loại máng và vật phẩm thức ăn.
signal serving_consumed(kind: int, item: ItemDefinition)
## Kết quả một bước di chuyển đến máng.
enum Travel { MOVING, ARRIVED, FAILED }
## Cấu hình loài và ngưỡng tìm thức ăn, nước.
var definition: AnimalDefinition
## Component quản lý độ no và nước.
var needs: AnimalNeedsComponent
## Component di chuyển và thông tin chuồng.
var wander: AnimalWanderComponent
## Máng đã chọn và giữ chỗ.
var target: AnimalTrough
## Chỉ số vị trí tiếp cận đã giữ trong máng.
var target_slot: int = -1
var _retry_remaining: float = 0.0
var _travel_remaining: float = 0.0
var _blocked: Dictionary[int, float] = {}

## Gắn cấu hình và các component cần thiết trước khi tìm nguồn.
func configure(data: AnimalDefinition, needs_component: AnimalNeedsComponent, wander_component: AnimalWanderComponent) -> void:
	definition = data
	needs = needs_component
	wander = wander_component

## Giảm thời gian chờ thử lại và thời gian tạm chặn các máng thất bại.
func advance(delta: float) -> void:
	_retry_remaining = maxf(0.0, _retry_remaining - delta)
	for identity: int in _blocked.keys():
		_blocked[identity] -= delta
		if _blocked[identity] <= 0.0:
			_blocked.erase(identity)

## Kiểm tra độ no hoặc nước đã tới ngưỡng tìm nguồn.
func has_need() -> bool:
	return definition != null and (needs.satiety <= definition.food_seek_threshold or needs.hydration <= definition.water_seek_threshold)

## Trả thứ tự loại máng cần tìm; khi cần cả hai, ưu tiên chỉ số thấp hơn.
func priority_kinds() -> Array[int]:
	var kinds: Array[int] = []
	if needs.hydration <= definition.water_seek_threshold:
		kinds.append(AnimalTrough.Kind.WATER)
	if needs.satiety <= definition.food_seek_threshold:
		if kinds.is_empty() or needs.satiety < needs.hydration:
			kinds.push_front(AnimalTrough.Kind.FOOD)
		else:
			kinds.append(AnimalTrough.Kind.FOOD)
	return kinds

# Tìm nguồn đáp ứng nhu cầu cấp bách trong đúng chuồng, rồi chọn điểm tiếp cận gần và đi tới được.
# Khoảng cách dùng bình phương để so sánh mà không tính căn bậc hai cho mọi ứng viên.
# Phải kiểm tra cả điểm đến lẫn tuyến đường: máng gần nhất sau tường không phải lựa chọn hợp lệ.
# Khoảng nghỉ thử lại và danh sách nguồn vừa thất bại giúp tránh chạy lại tìm kiếm nặng mỗi frame;
# đây là lựa chọn tối ưu có thể chỉnh, nhưng cần giữ kiểm tra đường và đặt chỗ trước khi đi.
## Tìm điểm tiếp cận gần nhất đi tới được trong các máng cùng chuồng, theo ưu tiên.
## Giữ chỗ trước khi đặt đường đi. Nguồn vừa thất bại tạm thời được bỏ qua.
## Trả true nếu đã giữ chỗ và bắt đầu đi.
func try_begin() -> bool:
	if definition == null or not is_instance_valid(wander.pen) or _retry_remaining > 0.0 or not has_need():
		return false
	_retry_remaining = 0.75
	for supply_kind: int in priority_kinds():
		var best: AnimalTrough = null
		var best_slot: int = -1
		var best_distance: float = INF
		for candidate: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
			var trough: AnimalTrough = candidate as AnimalTrough
			if trough == null or trough.is_queued_for_deletion() or trough.pen != wander.pen or trough.kind != supply_kind or not trough.can_supply(definition) or _blocked.has(trough.get_instance_id()):
				continue
			for slot: int in range(trough.access_offsets.size()):
				var point: Vector2 = trough.access_position(slot)
				var distance: float = wander.movement.body.global_position.distance_squared_to(point)
				if distance >= best_distance or not trough.slot_available(slot, wander.movement.body) or not wander.pen.contains_world(point, wander.margin):
					continue
				if not wander._target_is_clear(point) or not _path_is_clear(point):
					continue
				best = trough
				best_slot = slot
				best_distance = distance
		if best != null and best.claim(wander.movement.body, best_slot, definition):
			target = best
			target_slot = best_slot
			if not wander.set_destination(best.access_position(best_slot)):
				cancel(true)
				return false
			_travel_remaining = maxf(5.0, wander.route_distance() / maxf(1.0, wander.movement.speed) * 2.0 + 2.0)
			return true
	return false

## Kiểm tra máng còn tồn tại, còn cung cấp được và actor vẫn giữ vị trí tiếp cận.
func target_is_valid() -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and is_instance_valid(wander.pen) and target.pen == wander.pen and target.can_supply(definition) and target.owns_slot(wander.movement.body, target_slot) and target_slot >= 0 and target_slot < target.access_offsets.size() and wander.pen.contains_world(target.access_position(target_slot), wander.margin)

## Đi một bước đến vị trí đã giữ, cập nhật hoạt ảnh và trả trạng thái di chuyển.
## Thất bại nếu mục tiêu thay đổi, đường bị mất hoặc hết thời gian đi.
func step(delta: float) -> Travel:
	if not target_is_valid():
		return Travel.FAILED
	var body: CharacterBody2D = wander.movement.body
	var point: Vector2 = target.access_position(target_slot)
	# A moved trough invalidates the current trip instead of feeding at a stale point.
	if not wander.destination_matches(point):
		return Travel.FAILED
	if body.global_position.distance_to(point) <= 2.0:
		wander.movement.cancel_target()
		wander.movement.stop()
		wander.animation.face(target.global_position - body.global_position)
		return Travel.ARRIVED
	if not wander.movement.has_target:
		return Travel.FAILED
	_travel_remaining -= delta
	if _travel_remaining <= 0.0:
		return Travel.FAILED
	var before: Vector2 = body.global_position
	wander.move_to_destination(delta)
	wander._keep_inside()
	var displacement: Vector2 = body.global_position - before
	wander.animation.update_facing_direction(displacement)
	wander.animation.play("walk" if not displacement.is_zero_approx() else "idle")
	return Travel.MOVING

## Nhận khẩu phần từ máng hợp lệ và trả mức nhu cầu thực tế được phục hồi.
func finish() -> float:
	if not target_is_valid():
		return 0.0
	var kind: int = int(target.kind)
	var item: ItemDefinition = target.feed_item
	var restored: float = target.serve(wander.movement.body, needs, definition, target_slot)
	if restored > 0.0:
		serving_consumed.emit(kind, item)
	return restored

## Nhả chỗ, xóa mục tiêu và dừng di chuyển. Khi thất bại, tạm tránh máng đó.
func cancel(failed: bool = false) -> void:
	if is_instance_valid(target):
		if failed:
			_blocked[target.get_instance_id()] = 3.0
		target.release(wander.movement.body)
	target = null
	target_slot = -1
	if wander != null:
		wander.cancel_destination()

func _exit_tree() -> void:
	cancel()

func _path_is_clear(point: Vector2) -> bool:
	if wander.traversal != null:
		return wander.traversal.can_reach(point)
	if wander.collision == null or wander.collision.shape == null:
		return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = wander.collision.shape
	query.transform = wander.collision.global_transform
	query.motion = point - wander.movement.body.global_position
	query.collision_mask = wander.movement.body.collision_mask
	query.exclude = [wander.movement.body.get_rid()]
	var fractions: PackedFloat32Array = wander.movement.body.get_world_2d().direct_space_state.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0
