@tool
class_name PotDefinition
extends Resource
## Cấu hình hình ảnh của chậu hoa dùng trong editor và khi chạy game.
##
## FlowerPot quản lý trạng thái gameplay của chậu. Khi sửa các thuộc tính,
## resource phát tín hiệu thay đổi để nơi sử dụng cập nhật hình ảnh.

## Mã nhận diện kiểu chậu.
@export var pot_id: StringName = &"clay":
	set(value):
		pot_id = value
		emit_changed()
## Ảnh của chậu.
@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
## Độ lệch ảnh chậu so với gốc hiển thị.
@export var pot_offset: Vector2 = Vector2(-16, -24):
	set(value):
		pot_offset = value
		emit_changed()
## Vị trí neo hình cây tương đối với gốc chậu.
@export var plant_socket: Vector2 = Vector2(0, -15):
	set(value):
		plant_socket = value
		emit_changed()
