class_name WaterfowlComponent
extends Node
## Điều hướng vật nuôi trong ao và đưa sản phẩm cần đẻ trên đất vào bờ.
##
## Component nối với hệ thống đi lang thang và ánh xạ hoạt ảnh bơi theo vị trí.

## Vật nuôi được điều khiển.
var actor: AnimalActor
## Ao cung cấp truy vấn địa hình và đường đi.
var pen: PondPen
var _points: PackedVector2Array = PackedVector2Array()
var _next: int = 0
## Điểm đích cuối của đường đi hiện tại.
var destination: Vector2
var _returning: bool = false
var _was_swimming: bool = false
var _recovering: bool = false
var _seeking_shore: bool = false

## Gắn actor và ao, đăng ký bộ điều hướng và ánh xạ hoạt ảnh.
func configure(body: AnimalActor, habitat: PondPen) -> void:
	actor = body
	pen = habitat
	actor.wander.traversal = self
	actor.animation.action_mapper = map_action
	actor.animation.play("idle", true)

## Kiểm tra con vật có khả năng bơi và đang đứng trên nước.
func is_swimming() -> bool:
	return actor.definition.can_swim and pen.is_water(actor.global_position)

## Đổi hoạt ảnh đi, ngủ hoặc đứng sang hoạt ảnh bơi tương ứng khi ở nước.
func map_action(action: String) -> String:
	if not is_swimming():
		return action
	if action == "walk":
		return "swim"
	return "swim_sleep" if action == "sleep" else "swim_idle"

## Cập nhật vị trí hiển thị khi chuyển giữa nước và đất.
## Vật không biết bơi được đưa về đất gần nhất nếu đang ở nước.
func refresh_visual() -> void:
	if not pen.navigation_ready:
		return
	if not actor.definition.can_swim and pen.is_water(actor.global_position):
		actor.global_position = pen.closest_land(actor.global_position)
		cancel()
	var swimming: bool = is_swimming()
	if swimming != _was_swimming:
		_was_swimming = swimming
		actor.animation.play(actor.animation.current_action)
		var texture: Texture2D = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, 0)
		var used: Rect2i = texture.get_image().get_used_rect()
		actor.sprite.position.y = texture.get_height() * 0.5 - used.end.y
		actor.needs_display.position.y = actor.sprite.position.y - texture.get_height() * 0.5 + used.position.y - 18.0

## Kiểm tra có đường đi từ vị trí hiện tại đến điểm đích.
func can_reach(point: Vector2) -> bool:
	return not requires_shore_rest() and not pen.route(actor.global_position, point, actor.definition.can_swim).is_empty()

## Tìm đường và đặt waypoint đầu tiên. Trả false nếu không tìm được đường.
func set_destination(point: Vector2) -> bool:
	if requires_shore_rest():
		return false
	_points = pen.route(actor.global_position, point, actor.definition.can_swim)
	_next = 0
	destination = point
	if _points.is_empty():
		actor.movement.cancel_target()
		return false
	actor.movement.set_target(_points[_next])
	return true

## Tính tổng chiều dài còn lại từ vị trí hiện tại qua các waypoint.
func distance_remaining() -> float:
	var distance: float = 0.0
	var before: Vector2 = actor.global_position
	for index: int in range(_next, _points.size()):
		distance += before.distance_to(_points[index])
		before = _points[index]
	return distance

## Xóa đường đi và dừng chuyển động.
func cancel() -> void:
	_points.clear()
	_next = 0
	actor.movement.cancel_target()
	actor.movement.stop()

## Di chuyển đến waypoint tiếp theo, hủy đường nếu waypoint hiện tại bị chặn.
func travel(delta: float) -> void:
	actor.movement.move_to_target(delta)
	if not actor.movement.has_target:
		# A blocked waypoint invalidates the route; never skip through a wall.
		if _next < _points.size() and actor.global_position.distance_to(_points[_next]) > 2.0:
			cancel()
			return
		_next += 1
		if _next < _points.size():
			actor.movement.set_target(_points[_next])

func requires_shore_rest() -> bool:
	return actor.health.sick

func ready_for_shore_care() -> bool:
	return not _seeking_shore and not pen.is_water(actor.global_position)

## Recovering birds take priority over ordinary activity and care holds.
func handle_sickness(delta: float) -> bool:
	if not requires_shore_rest():
		if _recovering:
			_recovering = false
			_seeking_shore = false
			actor.behaviour.resume_after_shore_rest()
		return false
	var on_water: bool = pen.is_water(actor.global_position)
	var just_reached_shore: bool = not _recovering and not on_water
	if not _recovering or (on_water and not _seeking_shore):
		_recovering = true
		_returning = false
		_seeking_shore = on_water
		actor.behaviour.begin_shore_rest(on_water)
	if _seeking_shore:
		if not pen.navigation_ready:
			return true
		if not actor.movement.has_target and on_water:
			_points = pen.land_route(actor.global_position)
			_next = 0
			if _points.is_empty():
				return true
			destination = _points[-1]
			actor.movement.set_target(_points[0])
		if actor.movement.has_target:
			var before: Vector2 = actor.global_position
			travel(delta)
			actor.animation.update_facing_direction(actor.global_position - before)
			actor.animation.play("walk")
		if actor.movement.has_target or pen.is_water(actor.global_position):
			return true
		_seeking_shore = false
		just_reached_shore = true
	actor.behaviour.sit_for_treatment()
	if just_reached_shore:
		actor.shore_ready_for_care.emit()
	return true

# Trứng đã hoàn thành dưới nước được giữ ở production stock, chưa sinh ItemPickup.
# Vịt cần tìm đường lên bờ; đến đất mới chuyển stock sang đống trứng và giải phóng lộ trình.
# Nếu chỉ tạo pickup ngay khi đủ chu kỳ, trứng sẽ rơi dưới ao. Nếu chỉ xóa phần đã đẻ
# trước khi tìm được bờ, đường đi thất bại có thể làm mất sản phẩm.
## Đưa vật nuôi mang sản phẩm cần đẻ trên đất từ nước lên bờ.
## Sản phẩm được giữ trong kho của actor cho đến khi lên đất. Trả true khi
## thao tác lên bờ đang chiếm quyền xử lý hành vi.
func handle_laying(delta: float) -> bool:
	if not actor.definition.eggs_on_land or actor.production.stored_amount <= 0:
		return false
	if not pen.is_water(actor.global_position):
		if _returning:
			_returning = false
			cancel()
			actor.behaviour.request_behaviour(&"idle")
		actor._on_produced(0)
		return false
	if not pen.navigation_ready:
		return true
	if actor.behaviour.current_state in [AnimalBehaviourComponent.State.REST, AnimalBehaviourComponent.State.SLEEP]:
		actor.behaviour.wake()
		return true
	if not _returning or not actor.movement.has_target:
		actor.foraging.cancel()
		actor.behaviour.request_behaviour(&"idle")
		_points = pen.land_route(actor.global_position)
		_next = 0
		if _points.is_empty():
			actor.movement.stop()
			return true
		destination = _points[-1]
		actor.movement.set_target(_points[0])
		_returning = true
	var before: Vector2 = actor.global_position
	travel(delta)
	var motion: Vector2 = actor.global_position - before
	actor.animation.update_facing_direction(motion)
	actor.animation.play("walk" if not motion.is_zero_approx() else "idle")
	return true
