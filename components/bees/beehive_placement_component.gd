class_name BeehivePlacementComponent
extends Node2D
## Nhận input đặt tổ ong và hiển thị vị trí, phạm vi xem trước.
## ApiarySystem thực hiện kiểm tra và thay đổi inventory, thế giới.

## Phát khi thời hạn phản hồi thay đổi.
signal feedback_changed
## Người chơi đặt tổ.
var player: FarmPlayer
## Hiển thị phạm vi và tính hợp lệ của vị trí.
var range_display: BeehiveRangeDisplay
## Ảnh tổ xem trước.
var ghost: Sprite2D
var _feedback: String = ""
var _feedback_until: int = 0:
	set(value):
		_feedback_until = value
		feedback_changed.emit()

func _ready() -> void:
	range_display = BeehiveRangeDisplay.new()
	range_display.footprint = true
	range_display.z_index = 50
	add_child(range_display)
	ghost = Sprite2D.new()
	ghost.texture = preload("res://resources/bees/beehive.tres").idle_texture
	ghost.position.y = -8
	range_display.add_child(ghost)
	range_display.hide()

## Lấy hệ thống ong từ bộ điều khiển ruộng, hoặc null.
func apiary() -> ApiarySystem:
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	return farm.apiary if farm != null else null

## Kiểm tra người chơi đang chọn vật phẩm tổ ong.
func selected() -> bool:
	var item: ItemDefinition = player.selection.get_selected_item()
	return apiary() != null and item == apiary().definition.hive_item

func _process(_delta: float) -> void:
	if not selected() or player.selection.is_menu_open():
		range_display.hide()
		return
	var system: ApiarySystem = apiary()
	var point: Vector2 = system.snap_position(action_point())
	range_display.global_position = point
	range_display.radius = system.effective_radius(system.clock.now())
	range_display.allowed = system.placement_error(point).is_empty() and player.global_position.distance_to(point) <= 96.0
	ghost.modulate = Color(1,1,1,0.7) if range_display.allowed else Color(1,0.35,0.3,0.7)
	range_display.queue_redraw()
	range_display.show()

## Điểm đặt toàn cục: phía trước người chơi trên cảm ứng, vị trí chuột trên desktop.
func action_point() -> Vector2:
	if MobileLayout.is_touch(get_viewport()) or (player.mobile_controls != null and player.mobile_controls.root.visible):
		return player.global_position + player.animation.facing_vector * 32.0
	return get_global_mouse_position()

## Xử lý yêu cầu đặt tại điểm nếu tổ ong đang được chọn, kèm phản hồi.
func click(point: Vector2) -> bool:
	if not selected():
		return false
	player.state.navigation.cancel()
	var result: Dictionary = apiary().place(point,player,player.selection.selected_index)
	_feedback = "Hive placed!" if result.ok else String(result.error)
	_feedback_until = Time.get_ticks_msec()+2000
	return true

## Trả phản hồi nguồn còn hạn hoặc hướng dẫn đặt tổ theo thiết bị.
func feedback_source() -> String:
	if Time.get_ticks_msec() < _feedback_until:
		return _feedback
	if not selected():
		return ""
	return "Tap nearby ground or press Use to place. Select another slot to cancel." if MobileLayout.is_touch(get_viewport()) else "Left-click nearby ground to place. Select another slot to cancel."

## Thời điểm hết hạn phản hồi theo ticks mili giây, hoặc 0 nếu không có.
func feedback_expires_at() -> int:
	return _feedback_until if not _feedback.is_empty() else 0
