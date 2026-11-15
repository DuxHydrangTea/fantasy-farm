class_name AnimationComponent
extends Node
## Chọn và phát hoạt ảnh theo hành động và hướng nhìn của nhân vật.
## Hỗ trợ sprite một hướng, lật ảnh, hoạt ảnh dự phòng và ánh xạ hành động.

## Phát hành động logic khi hoạt ảnh hiện tại kết thúc.
signal action_finished(action: String)

## Sprite được điều khiển.
@export var animated_sprite: AnimatedSprite2D
## Hoạt ảnh dùng khi không tìm thấy hành động theo hướng.
@export var fallback_animation: StringName = &"idle_down"
## Cho phép dùng ảnh hướng phải và lật để thể hiện hướng trái.
@export var flip_left: bool = true
## Dùng bộ ảnh một hướng và lật ngang theo hướng nhìn.
@export var single_direction: bool = false
## Hướng nhìn gốc của ảnh một hướng.
@export var single_direction_faces_left: bool = true # Cho biết ảnh gốc nhìn trái hay phải, để lật đúng hướng.

## Vector đơn vị tương ứng từng tên hướng.
const DIR_VECTORS: Dictionary[StringName, Vector2] = {
	&"down": Vector2.DOWN,
	&"up": Vector2.UP,
	&"left": Vector2.LEFT,
	&"right": Vector2.RIGHT,
}

## Tên hướng nhìn hiện tại.
var facing_direction: StringName = &"down"
## Hành động logic đang phát.
var current_action: String = ""
## Hàm tùy chọn đổi hành động hiển thị; signal hoàn tất vẫn dùng hành động gốc.
var action_mapper: Callable
var _warned: Dictionary[StringName, bool] = {}
## Vector đơn vị của hướng nhìn hiện tại.
var facing_vector: Vector2:
	get:
		return DIR_VECTORS[facing_direction]

# Frame tác động không được vượt số frame thật của animation.
# Ví dụ cấu hình muốn frame 3 nhưng clip chỉ có 2 frame (0,1): kẹp về 1 để thao tác vẫn xảy ra.
# Clip một frame cần handler animation_changed đã nối deferred ở các component tương tác;
# chỉ nghe frame_changed có thể bỏ lỡ vì frame vẫn là 0. Không kẹp thì clip ngắn không bao giờ commit.
## Kiểm tra sprite đã tới frame tác động; frame yêu cầu được kẹp vào clip.
## Trả false nếu sprite, bộ khung hoặc hoạt ảnh không có frame.
func impact_reached(requested_frame: int) -> bool:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	var count: int = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
	return count > 0 and animated_sprite.frame >= clampi(requested_frame, 0, count - 1)

func _ready() -> void:
	assert(animated_sprite != null, "AnimationComponent: chua gan animted_sprite")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
## Phát hành động theo hướng hiện tại, dùng hoạt ảnh dự phòng nếu thiếu clip.
## Khi [param force_restart] bật, dừng và phát lại ngay cả khi clip đang chạy.
func play(action: String, force_restart: bool = false) -> void:
	if animated_sprite.sprite_frames == null:
		return
	current_action = action
	
	var flip := false
	var dir := facing_direction
	if single_direction:
		dir = &"down"
		
		if single_direction_faces_left:
			flip = facing_direction == &"right"
		else:
			flip = facing_direction == &"left"
	elif dir == &"left" and flip_left:
		dir = &"right"
		flip = true
		
	var visual_action: String = String(action_mapper.call(action)) if action_mapper.is_valid() else action
	var animation_name := StringName("%s_%s" % [visual_action, dir])
	
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		_warn_once(animation_name)
		animation_name = fallback_animation
		flip = false
	
	animated_sprite.flip_h = flip
	
	if animated_sprite.animation == animation_name and animated_sprite.is_playing() and not force_restart:
		return

	if force_restart:
		animated_sprite.stop()
	
	animated_sprite.play(animation_name)

func _warn_once(animation_name: StringName):
	if _warned.has(animation_name):
		return
	_warned[animation_name] = true
	push_warning("AnimationComponent (%s): thiếu animation '%s'" % [owner.name, animation_name])

func _on_animation_finished():
	action_finished.emit(current_action)

## Cập nhật hướng nhìn theo thành phần trội của vector và trả true nếu hướng đổi.
## Vector 0 giữ nguyên hướng. Khi hai thành phần bằng nhau, ưu tiên giữ hướng cũ.
func update_facing_direction(dir: Vector2) -> bool:
	if dir.is_zero_approx():
		return false
		
	var old := facing_direction
	
	if single_direction:
		if not is_zero_approx(dir.x):
			facing_direction = &"right" if dir.x > 0.0 else &"left"
			
		return facing_direction != old
	
	var horizontal: StringName = &"right" if dir.x > 0 else &"left"
	var vertical: StringName = &"down" if dir.y > 0 else &"up"
	
	if absf(dir.x) > absf(dir.y):
		facing_direction = horizontal
	elif absf(dir.y) > absf(dir.x):
		facing_direction = vertical
	elif facing_direction != horizontal and facing_direction != vertical:
		facing_direction = horizontal
	
	return facing_direction != old

## Đổi hướng nhìn và phát lại hành động hiện tại nếu hướng thay đổi.
func face(dir: Vector2) ->void:
	if update_facing_direction(dir) and current_action:
		play(current_action)
