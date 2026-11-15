class_name AnimalDefinition
extends Resource
## Cấu hình dùng chung của một loại vật nuôi.
##
## Resource chứa các thông số di chuyển, hành vi, nhu cầu, hình ảnh, môi
## trường sống và vòng đời. Trạng thái của từng con được quản lý riêng.

## Mã ổn định nhận diện loại vật nuôi.
@export var animal_id: StringName
## Tên hiển thị.
@export var display_name: String
## Loài vật nuôi.
@export var species: AnimalTypes.Species = AnimalTypes.Species.CHICKEN
@export_group("Movement")
## Tốc độ di chuyển theo đơn vị thế giới mỗi giây.
@export_range(1.0, 150.0) var move_speed: float = 28.0
## Khoảng thời gian đứng yên tối thiểu và tối đa, tính bằng giây.
@export var idle_seconds: Vector2 = Vector2(0.6, 1.8)
## Kích thước vùng chiếm chỗ của con vật.
@export var footprint: Vector2 = Vector2(10, 6)
## Khoảng cách chừa ở rìa chuồng khi chọn vị trí.
@export_range(1.0, 64.0) var pen_margin: float = 12.0
@export_group("Behaviour")
## Trọng số tương đối khi chọn hành động đi lại.
@export_range(0.0, 20.0) var walk_weight: float = 5.0
## Trọng số tương đối khi chọn hành động kiếm ăn.
@export_range(0.0, 20.0) var forage_weight: float = 3.0
## Trọng số tương đối khi chọn hành động nghỉ.
@export_range(0.0, 20.0) var rest_weight: float = 1.0
## Trọng số tương đối khi chọn hành động ngủ.
@export_range(0.0, 20.0) var sleep_weight: float = 1.0
## Khoảng thời gian kiếm ăn tối thiểu và tối đa, tính bằng giây.
@export var forage_seconds: Vector2 = Vector2(1.5, 3.5)
## Khoảng thời gian nghỉ tối thiểu và tối đa, tính bằng giây.
@export var rest_seconds: Vector2 = Vector2(2.0, 4.0)
## Khoảng thời gian ngủ tối thiểu và tối đa, tính bằng giây.
@export var sleep_seconds: Vector2 = Vector2(4.0, 8.0)
## Tên hoạt ảnh kiếm ăn. Để trống để chọn hoạt ảnh được hỗ trợ đầu tiên.
@export var forage_action: StringName = &""
## Tên hoạt ảnh nằm nghỉ. Để trống để chọn hoạt ảnh được hỗ trợ đầu tiên.
@export var lie_down_action: StringName = &""
@export_group("Needs")
## Thời gian cạn độ no, tính bằng giây.
@export_range(1.0, 86400.0) var satiety_depletion_seconds: float = 600.0
## Thời gian cạn độ nước, tính bằng giây.
@export_range(1.0, 86400.0) var hydration_depletion_seconds: float = 600.0
## Lượng thức ăn tiêu thụ mỗi bữa.
@export_range(1, 32000) var food_per_meal: int = 1
## Lượng nước tiêu thụ mỗi lần uống.
@export_range(1, 32000) var water_per_drink: int = 1
## Ngưỡng độ no kích hoạt tìm thức ăn.
@export_range(0.0, 100.0) var food_seek_threshold: float = 50.0
## Ngưỡng độ nước kích hoạt tìm nước.
@export_range(0.0, 100.0) var water_seek_threshold: float = 50.0
@export_group("Visuals")
## Bộ khung hoạt ảnh con trưởng thành.
@export var adult_frames: SpriteFrames
## Bộ khung hoạt ảnh con non, có thể thiếu nếu dùng hình con trưởng thành.
@export var juvenile_frames: SpriteFrames
## Cho biết hướng gốc của sprite là hướng trái.
@export var faces_left: bool = true
@export_group("Habitat")
## Cho phép vật nuôi bơi.
@export var can_swim: bool = false
## Cho biết trứng được đặt trên đất.
@export var eggs_on_land: bool = false
@export_group("Growth And Production")
## Tuổi trưởng thành tính bằng giây kể từ khi sinh.
@export_range(0.0, 1209600.0) var maturity_seconds: float = 86400.0
## Tuổi thọ tính bằng giây từ lúc sinh, bao gồm cả giai đoạn non và thời gian offline.
@export_range(1.0, 31536000.0) var lifespan_seconds: float = 1209600.0
## Cấu hình chu kỳ và loại sản phẩm vật nuôi tạo ra.
@export var production: AnimalProductionDefinition

## Kiểm tra mã, hoạt ảnh trưởng thành, kích thước, tốc độ, nhu cầu và vòng đời.
## Tuổi thọ phải hữu hạn và lớn hơn tuổi trưởng thành.
func is_valid() -> bool:
	return not animal_id.is_empty() and has_movement_frames(adult_frames) and move_speed > 0.0 and footprint.x > 0.0 and footprint.y > 0.0 and satiety_depletion_seconds > 0.0 and hydration_depletion_seconds > 0.0 and idle_seconds.x >= 0.0 and idle_seconds.y >= idle_seconds.x and is_finite(maturity_seconds) and maturity_seconds >= 0.0 and is_finite(lifespan_seconds) and lifespan_seconds > maturity_seconds

## Kiểm tra bộ khung có ít nhất một khung cho idle_down và walk_down.
func has_movement_frames(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation(&"idle_down") and frames.has_animation(&"walk_down") and frames.get_frame_count(&"idle_down") > 0 and frames.get_frame_count(&"walk_down") > 0

## Chọn bộ khung cho giai đoạn tuổi. Nếu bộ con non thiếu hoạt ảnh di chuyển
## hợp lệ, trả về bộ trưởng thành.
func get_frames_for_stage(is_adult: bool) -> SpriteFrames:
	return adult_frames if is_adult or not has_movement_frames(juvenile_frames) else juvenile_frames
