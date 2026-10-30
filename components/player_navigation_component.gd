class_name PlayerNavigationComponent
extends Node
## Approach a clicked focus point using the player's real collision footprint.

signal focus_finished(reached: bool)
signal focus_cancelled
var _interaction_goal: Callable
var _interaction_reach: float = 20.0

@export var movement: MovementComponent
@export var animation: AnimationComponent
@export var camera: Camera2D
@export var collision_shape: CollisionShape2D
@export var farming_actions: FarmingActionComponent
@export_range(4.0, 16.0, 1.0) var cell_size: float = 8.0
@export_range(8.0, 32.0, 1.0) var interaction_distance: float = 20.0
@export var allow_focus_cell: bool = false

var has_focus: bool = false
var is_navigating: bool = false
var focus_position: Vector2 = Vector2.ZERO
# NGÂN SÁCH DÒ Ô — tối ưu độ mượt, không phải quy tắc gameplay bắt buộc.
# Mỗi tick chỉ dò thêm tối đa số ô chưa biết này bằng physics; các kiểm tra đường đi trực tiếp
# và rút gọn đường có giới hạn riêng. Không nên hiểu đây là giới hạn mọi truy vấn physics.
# Nếu dò cả map ngay ở mỗi click, một khung hình có thể phải chạy hàng nghìn truy vấn và giật.
# Đổi lại, lần click đầu ở vùng chưa có cache có thể chờ vài tick; lần sau tận dụng kết quả cũ.
@export_range(16, 512, 16) var sampling_budget: int = 256
var _sampled: Dictionary[Vector2i, bool] = {}
var _regions: Array[Rect2i] = []
var _region_index: int = 0
var _scan_cursor: int = 0
var _background_cursor: int = 0
var _planning: bool = false
var _invalidate_pending: bool = false
var _footprint_signature: Array = []
var total_physics_queries: int = 0
var _shared_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _grid: AStarGrid2D
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _needs_path: bool = false
var _replans: int = 0
var _blocked_cells: Dictionary[Vector2i, bool] = {}

func _ready() -> void:
	assert(movement != null and animation != null and camera != null and collision_shape != null,
		"Assign player navigation references")
	get_tree().node_added.connect(_geometry_changed)
	get_tree().node_removed.connect(_geometry_changed)
	_connect_tile_changes.call_deferred()

func _connect_tile_changes() -> void:
	var farm: FarmingController = farming_actions.get_farming_controller() if farming_actions != null else null
	if farm != null:
		for child: Node in farm.get_parent().get_children():
			if child is TileMapLayer and child.tile_set != null and child.tile_set.get_physics_layers_count() > 0:
				child.changed.connect(invalidate_cache)

func _geometry_changed(node: Node) -> void:
	if node is StaticBody2D and not _invalidate_pending:
		_invalidate_pending = true
		invalidate_cache.call_deferred()

# Cache chỉ đúng khi vật cản và kích thước chân va chạm còn như lúc dò.
# Thêm/xóa công trình hoặc đổi TileMap phải vô hiệu hóa cache để A* không dùng đường cũ.
# Ô chưa dò lại được xem là bị chặn (bảo thủ): không suy đoán rằng nơi chưa biết chắc đi được.
# Nếu bỏ bước này, player có thể liên tục chọn đường xuyên qua vật vừa được đặt.
func invalidate_cache() -> void:
	_invalidate_pending = false
	_sampled.clear()
	_blocked_cells.clear()
	_background_cursor = 0
	if _grid != null:
		_grid.fill_solid_region(_grid.region, true)
	if has_focus and is_navigating:
		_needs_path = true

func invalidate_region(world_rect: Rect2) -> void:
	if _grid == null:
		return
	var area: Rect2i = Rect2i(_cell(world_rect.position), Vector2i.ONE).expand(_cell(world_rect.end)).grow(1).intersection(_grid.region)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var cell: Vector2i = Vector2i(x, y)
			_sampled.erase(cell)
			_grid.set_point_solid(cell, true)

func _physics_process(_delta: float) -> void:
	if is_navigating:
		return
	_prepare_grid()
	var left: int = sampling_budget
	while _background_cursor < _grid.region.size.x * _grid.region.size.y and left > 0:
		var cell: Vector2i = _scan_cell(_grid.region, _background_cursor)
		_background_cursor += 1
		if not _sampled.has(cell):
			_sample(cell)
			left -= 1

func request_focus(point: Vector2) -> void:
	_request(point, interaction_distance, Callable())

func _request(point: Vector2, reach: float, validator: Callable) -> void:
	if is_navigating and focus_position.is_equal_approx(point) and _interaction_goal == validator and is_equal_approx(_interaction_reach, reach):
		return
	# Đổi lệnh hủy hành động tương tác cũ, nhưng giữ đường và vận tốc đang đi.
	# Đường cũ chỉ được dùng tiếp sau khi quét va chạm, tới khi đường mới sẵn sàng.
	focus_cancelled.emit()
	_interaction_goal = validator
	_interaction_reach = reach
	focus_position = point
	has_focus = true
	is_navigating = true
	# Click lệch nhẹ nhưng điểm đứng cuối vẫn hợp lệ: dùng luôn đường hiện tại.
	# Tránh chạy lại A* chỉ vì con trỏ đổi vài pixel, vẫn giữ chính xác focus mới.
	_needs_path = _path.is_empty() or not _goal_valid(_path[_path.size() - 1])
	_planning = false
	_replans = 0
	_blocked_cells.clear()

func cancel() -> void:
	_interaction_goal = Callable()
	focus_cancelled.emit()
	has_focus = false
	is_navigating = false
	_needs_path = false
	_path.clear()
	_path_index = 0
	_planning = false
	_replans = 0
	_blocked_cells.clear()
	movement.cancel_target()

func move(delta: float) -> void:
	if not has_focus:
		return
	if _needs_path:
		_needs_path = false
		_start_plan()
	if _planning:
		_advance_plan()
		if _planning and _path.is_empty():
			movement.stop()
			return
	if not is_navigating:
		movement.stop()
		_face_focus()
		return
	while _path_index < _path.size() and movement.body.global_position.distance_to(_path[_path_index]) <= movement.arrival_distance:
		_path_index += 1
	if _path_index >= _path.size():
		if _planning:
			movement.cancel_target()
			movement.stop()
		else:
			_finish()
		return
	var waypoint: Vector2 = _path[_path_index]
	# Recheck shortcuts while walking so old grid turns do not cause zigzags.
	var checks: int = 0
	for index: int in range(_path.size() - 1, _path_index, -1):
		if checks >= 8:
			break
		checks += 1
		if _segment_clear(movement.body.global_position, _path[index]):
			_path_index = index
			waypoint = _path[index]
			break
	if not _segment_clear(movement.body.global_position, waypoint):
		if not _point_clear(waypoint):
			_blocked_cells[_cell(waypoint)] = true
		_replan()
		return
	if not movement.has_target or movement.target_position != waypoint:
		movement.set_target(waypoint)
	animation.update_facing_direction(movement.target_direction())
	movement.move_to_target(delta)
	if not movement.has_target and movement.body.global_position.distance_to(waypoint) > movement.arrival_distance:
		_replan()
	elif not _planning and _path_index == _path.size() - 1 and movement.body.global_position.distance_to(waypoint) <= movement.arrival_distance:
		_finish()

func _finish() -> void:
	var reached: bool = _in_focus_range(movement.body.global_position)
	is_navigating = false
	_path.clear()
	movement.cancel_target()
	movement.stop()
	_face_focus()
	focus_finished.emit(reached)

func _face_focus() -> void:
	animation.update_facing_direction(_facing_point() - movement.body.global_position)

func _facing_point() -> Vector2:
	if _interaction_goal.is_valid():
		return focus_position
	var farming: FarmingController = farming_actions.get_farming_controller() if farming_actions != null else null
	if farming == null:
		return focus_position
	# Clicking a tile corner still means facing that tile, not an adjacent one.
	return farming.farmland.to_global(farming.farmland.map_to_local(farming.world_to_cell(focus_position)))

func _replan() -> void:
	var region: Rect2 = Rect2(movement.body.global_position, Vector2.ZERO)
	if _path_index < _path.size():
		region = region.expand(_path[_path_index])
	invalidate_region(region.grow(64.0))
	# Vật cản mới làm đường cũ mất an toàn: bỏ đường đó trước khi dò lại.
	_path.clear()
	_path_index = 0
	movement.cancel_target()
	movement.stop()
	_replans += 1
	if _replans > 3:
		_finish()
	else:
		_needs_path = true

# Kiểm tra bằng hình va chạm thật của player, không chỉ ray từ một điểm.
# Tịnh tiến transform hiện tại đến điểm giả định để giữ cả offset, scale và rotation của chân.
# exclude bỏ chính body của player; nếu không, phép dò có thể luôn đụng bản thân.
# Ray kiểm tra tâm có thể báo khe hẹp là trống dù thân player không lọt, gây kẹt ở góc.
func _query(point: Vector2) -> PhysicsShapeQueryParameters2D:
	var query: PhysicsShapeQueryParameters2D = _shared_query
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.transform.origin += point - movement.body.global_position
	query.collision_mask = movement.body.collision_mask
	query.exclude = [movement.body.get_rid()]
	query.motion = Vector2.ZERO
	query.margin = 0.25
	return query

func _point_clear(point: Vector2) -> bool:
	total_physics_queries += 1
	return movement.body.get_world_2d().direct_space_state.intersect_shape(_query(point), 1).is_empty()

# Hai đầu đều trống không có nghĩa cả đoạn trống: giữa chúng có thể có hàng rào.
# cast_motion quét hình chân dọc đoạn và trả tỷ lệ quãng đường còn an toàn.
# Ngưỡng 0.9999 chấp nhận sai số số thực rất nhỏ ở cuối đoạn, không phải cho xuyên vật cản.
# Bỏ phép quét này có thể làm rút gọn đường A* thành đường thẳng cắt xuyên chướng ngại.
func _segment_clear(from: Vector2, to: Vector2) -> bool:
	if not _point_clear(to):
		return false
	var query: PhysicsShapeQueryParameters2D = _query(from)
	query.motion = to - from
	total_physics_queries += 1
	var fractions: PackedFloat32Array = movement.body.get_world_2d().direct_space_state.cast_motion(query)
	return fractions[0] >= 0.9999

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi((point.x - camera.limit_left) / cell_size) - 1,
		roundi((point.y - camera.limit_top) / cell_size) - 1)

func _point(cell: Vector2i) -> Vector2:
	return Vector2(camera.limit_left, camera.limit_top) + (Vector2(cell) + Vector2.ONE) * cell_size

func _in_focus_range(point: Vector2) -> bool:
	if _interaction_goal.is_valid():
		return point.distance_to(focus_position) <= _interaction_reach and bool(_interaction_goal.call(point))
	if point.distance_to(focus_position) > interaction_distance:
		return false
	var farming: FarmingController = farming_actions.get_farming_controller() if farming_actions != null else null
	if farming == null:
		return true
	# The farming tool acts on the adjacent cell in the facing direction.
	var offset: Vector2i = farming.world_to_cell(focus_position) - farming.world_to_cell(point)
	var direction: Vector2 = _facing_point() - point
	var facing: Vector2i = Vector2i(signi(offset.x), 0) if absf(direction.x) > absf(direction.y) else Vector2i(0, signi(offset.y))
	return absi(offset.x) + absi(offset.y) == 1 and offset == facing

# Đích là vị trí đứng cạnh ô cần tương tác, không phải chính ô cây/đồ vật được click.
# Movement cho phép dừng trong arrival_distance, nên kiểm tra cả bốn phía của vùng sai số.
# Nếu chỉ kiểm tra đúng tâm đích, player có thể dừng lệch sang ô khác rồi cuốc nhầm ô.
func _goal_valid(point: Vector2) -> bool:
	# Arrival has a tolerance: it must not leave the actor across a tile boundary.
	var margin: float = movement.arrival_distance + 0.25
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if not _in_focus_range(point + direction * margin):
			return false
	return _in_focus_range(point)

func _prepare_grid() -> void:
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(
		floori(float(camera.limit_right - camera.limit_left) / cell_size) - 1,
		floori(float(camera.limit_bottom - camera.limit_top) / cell_size) - 1))
	var footprint: Array = [collision_shape.shape.get_rid(), collision_shape.shape.get_rect(), collision_shape.transform, movement.body.global_scale, movement.body.global_rotation, movement.body.collision_mask]
	if _grid != null and _grid.region == bounds and _grid.cell_size == Vector2.ONE * cell_size and _grid.offset == Vector2(camera.limit_left, camera.limit_top) + Vector2.ONE * cell_size and footprint == _footprint_signature:
		return
	_footprint_signature = footprint
	_grid = AStarGrid2D.new()
	_grid.region = bounds
	_grid.cell_size = Vector2.ONE * cell_size
	_grid.offset = Vector2(camera.limit_left, camera.limit_top) + Vector2.ONE * cell_size
	# Chọn lưới bốn hướng để không cắt chéo góc tường; đây là lựa chọn thuật toán hiện tại.
	# Muốn cho đi chéo có thể đổi, nhưng phải bổ sung kiểm tra góc/hình chân tương ứng.
	# Chỉ bật đường chéo mà không kiểm tra có thể khiến A* chọn khe mà physics không đi qua được.
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	invalidate_cache()

func _scan_cell(region: Rect2i, cursor: int) -> Vector2i:
	return region.position + Vector2i(cursor % region.size.x, cursor / region.size.x)

func _sample(cell: Vector2i) -> void:
	var solid: bool = not _point_clear(_point(cell))
	_sampled[cell] = solid
	_grid.set_point_solid(cell, solid or _blocked_cells.has(cell))

# Dò từ hành lang quanh player–điểm click ra vùng rộng hơn (đệm 16, 64 ô rồi cả map).
# Vùng hẹp xử lý click gần nhanh; vùng rộng giúp tìm đường vòng khi có rào chắn dài.
# Các mức đệm là tham số tối ưu có thể thay, không phải khoảng cách tương tác.
# Nếu chỉ giữ vùng hẹp, đường vòng hợp lệ ngoài vùng đó sẽ bị báo là không đi tới được.
func _start_plan() -> void:
	_prepare_grid()
	_needs_path = false
	_planning = false
	var origin: Vector2 = movement.body.global_position
	if _in_focus_range(origin):
		_finish()
		return
	if not _grid.region.has_point(_cell(origin)) or not _grid.region.has_point(_cell(focus_position)):
		_finish()
		return
	# Lối thông không cần chờ dò lưới/A*: cập nhật ngay trong tick nhận lệnh.
	if _try_direct_path(origin):
		return
	var corridor: Rect2i = Rect2i(_cell(origin), Vector2i.ONE).expand(_cell(focus_position))
	_regions.clear()
	for padding: int in [16, 64]:
		var region: Rect2i = corridor.grow(padding).intersection(_grid.region)
		if not _regions.has(region):
			_regions.append(region)
	if not _regions.has(_grid.region):
		_regions.append(_grid.region)
	_region_index = 0
	_scan_cursor = 0
	_planning = true

func _try_direct_path(origin: Vector2) -> bool:
	var candidates: Array[Vector2] = []
	var focus_cell: Vector2i = _cell(focus_position)
	var reach: int = ceili((_interaction_reach if _interaction_goal.is_valid() else interaction_distance) / cell_size)
	for y: int in range(focus_cell.y - reach, focus_cell.y + reach + 1):
		for x: int in range(focus_cell.x - reach, focus_cell.x + reach + 1):
			var goal: Vector2i = Vector2i(x, y)
			if (allow_focus_cell or goal != focus_cell) and _grid.region.has_point(goal) and _goal_valid(_point(goal)):
				candidates.append(_point(goal))
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return origin.distance_squared_to(a) < origin.distance_squared_to(b))
	for goal: Vector2 in candidates:
		if _segment_clear(origin, goal):
			_path = PackedVector2Array([goal])
			_path_index = 0
			return true
	return false

func _advance_plan() -> void:
	var left: int = sampling_budget
	while _region_index < _regions.size():
		var region: Rect2i = _regions[_region_index]
		while _scan_cursor < region.size.x * region.size.y:
			var cell: Vector2i = _scan_cell(region, _scan_cursor)
			if not _sampled.has(cell):
				if left <= 0:
					return
				_sample(cell)
				left -= 1
			_scan_cursor += 1
		if _build_path_in_region(region):
			_planning = false
			return
		_region_index += 1
		_scan_cursor = 0
	_planning = false
	_finish()

# Chọn một điểm khởi đầu gần player có đoạn nối thật sự thông, rồi thử các ô đứng được
# quanh mục tiêu. Chi phí gồm khoảng cách tới ô bắt đầu + số bước bốn hướng nhân cell_size.
# Không bắt player đứng đè lên ô focus, vì ô đó có thể chứa cây, máng hoặc NPC.
# Nếu chỉ yêu cầu A* đi đến tâm điểm click, player có thể đứng sai chỗ để nông cụ tác động.
func _build_path_in_region(region: Rect2i) -> bool:
	var replacement: PackedVector2Array = PackedVector2Array()
	var origin: Vector2 = movement.body.global_position
	var start: Vector2i = Vector2i(-1, -1)
	var start_distance: float = INF
	var origin_cell: Vector2i = _cell(origin)
	for y: int in range(origin_cell.y - 2, origin_cell.y + 3):
		for x: int in range(origin_cell.x - 2, origin_cell.x + 3):
			var cell: Vector2i = Vector2i(x, y)
			if not _grid.region.has_point(cell) or _grid.is_point_solid(cell):
				continue
			var distance: float = origin.distance_squared_to(_point(cell))
			if distance < start_distance and _segment_clear(origin, _point(cell)):
				start = cell
				start_distance = distance
	if start == Vector2i(-1, -1):
		return false
	var focus_cell: Vector2i = _cell(focus_position)
	var reach: int = ceili((_interaction_reach if _interaction_goal.is_valid() else interaction_distance) / cell_size)
	var best_length: float = INF
	for y: int in range(focus_cell.y - reach, focus_cell.y + reach + 1):
		for x: int in range(focus_cell.x - reach, focus_cell.x + reach + 1):
			var goal: Vector2i = Vector2i(x, y)
			if (goal == focus_cell and not allow_focus_cell) or not _grid.region.has_point(goal) or _grid.is_point_solid(goal):
				continue
			if not _goal_valid(_point(goal)):
				continue
			var ids: Array[Vector2i] = _grid.get_id_path(start, goal)
			if ids.is_empty():
				continue
			var length: float = sqrt(start_distance) + float(ids.size() - 1) * cell_size
			if length >= best_length:
				continue
			best_length = length
			replacement.clear()
			for cell: Vector2i in ids:
				replacement.append(_point(cell))
	if replacement.is_empty():
		return false
	_path = replacement
	_path_index = 0
	_smooth_path(origin)
	return true

# Rút gọn đường là tối ưu/thẩm mỹ: bỏ điểm thẳng hàng trước, rồi thử nối tắt các góc.
# Giới hạn 32 phép thử nối tắt để việc làm đường đẹp không gây giật khi đường dài.
# Có thể bỏ bước này và vẫn đi theo A*, nhưng player sẽ qua nhiều waypoint hơn.
# Không được bỏ kiểm tra segment_clear khi nối tắt, nếu không sẽ cắt xuyên hàng rào.
func _smooth_path(origin: Vector2) -> void:
	# Collapse straight runs without physics work; cap optional corner shortcuts.
	var turns: PackedVector2Array = PackedVector2Array()
	for index: int in range(_path.size()):
		if index == 0 or index == _path.size() - 1 or (_path[index] - _path[index - 1]) != (_path[index + 1] - _path[index]):
			turns.append(_path[index])
	var smoothed: PackedVector2Array = PackedVector2Array()
	var next_index: int = 0
	var checks: int = 0
	while next_index < turns.size():
		var chosen: int = next_index
		for index: int in range(turns.size() - 1, next_index, -1):
			if checks >= 32:
				break
			checks += 1
			if _segment_clear(origin, turns[index]):
				chosen = index
				break
		origin = turns[chosen]
		smoothed.append(origin)
		next_index = chosen + 1
	_path = smoothed

func request_interaction(point: Vector2, reach: float, validator: Callable) -> void:
	_request(point, maxf(8.0, reach), validator)
