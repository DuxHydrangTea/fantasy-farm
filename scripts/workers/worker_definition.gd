class_name WorkerDefinition
extends Resource
## Cấu hình hình ảnh và tốc độ cho một loại công nhân.
##
## Chiến lược [WorkerRole] xử lý tìm việc, hành động và đóng góp khi offline.

## Mã công nhân dùng để nhận diện cấu hình.
@export var worker_id: StringName
## Tên hiển thị.
@export var display_name: String
## Các khung hoạt ảnh của công nhân.
@export var frames: SpriteFrames
## Tốc độ di chuyển theo đơn vị thế giới mỗi giây.
@export_range(20.0, 400.0) var move_speed: float = 120.0
## Thời gian làm một thao tác, tính bằng giây.
@export_range(0.5, 10.0) var work_seconds: float = 2.0
## Hướng nhìn gốc của ảnh sprite, dùng bởi AnimationComponent.
@export var faces_left: bool = true

## Kiểm tra có khung hoạt ảnh và mã công nhân không rỗng.
func is_valid() -> bool:
	return frames != null and worker_id != null and not String(worker_id).is_empty()
