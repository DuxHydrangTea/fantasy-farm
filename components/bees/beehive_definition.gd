class_name BeehiveDefinition
extends Resource
## Quy tắc và resource dùng chung của tổ ong; trạng thái từng tổ được lưu riêng.

## Lượng công việc cần để hoàn thành một mẻ, tính bằng giây cơ sở.
@export_range(1.0,604800.0) var cycle_seconds: float = 86400.0
## Bán kính tác động cơ sở.
@export_range(16.0,160.0) var radius: float = 80.0
## Hệ số tốc độ thụ phấn của mẻ cũ.
@export_range(1.0,3.0) var pollen_speed: float = 1.3
## Hệ số sản xuất với hoa hướng dương.
@export_range(1.0,3.0) var sunflower_speed: float = 4.0 / 3.0
## Hệ số sản xuất với các loài hoa đặc sản.
@export_range(1.0,3.0) var floral_speed: float = 2.0
## Số đơn vị mật trong một mẻ thông thường.
@export_range(1,32000) var batch_amount: int = 100
## Tỉ lệ thưởng cho cây trồng được thụ phấn.
@export_range(0.0,1.0) var crop_bonus: float = 0.1
## Tỉ lệ công việc tối thiểu một nguồn phải đóng góp để thành mật đặc sản.
@export_range(0.01,1.0) var specialty_ratio: float = 0.5
## Vật phẩm mật thường.
@export var wild_honey: ItemDefinition
## Vật phẩm mật hướng dương.
@export var sunflower_honey: ItemDefinition
## Vật phẩm mật hoa đặc sản.
@export var floral_honey: ItemDefinition
## Vật phẩm đặt tổ ong.
@export var hive_item: ItemDefinition
## Ảnh tổ chưa đầy.
@export var idle_texture: Texture2D
## Ảnh tổ có mẻ sẵn sàng thu.
@export var full_texture: Texture2D

## Kiểm tra mã thuộc nhóm năm loài hoa đặc sản.
func is_rare_flower(source: String) -> bool:
	return source in ["flower_06", "flower_07", "flower_08", "flower_09", "flower_10"]

## Kiểm tra nguồn là hướng dương hoặc hoa đặc sản.
func is_specialty(source: String) -> bool:
	return source == "sunflower" or is_rare_flower(source)

## Hệ số tích lũy công việc theo nguồn và quy tắc mẻ cũ nếu legacy bật.
func honey_rate(source: String, legacy: bool = false) -> float:
	if legacy:
		return pollen_speed if not source.is_empty() else 1.0
	return sunflower_speed if source == "sunflower" else floral_speed if is_rare_flower(source) else 1.0

## Chọn vật phẩm mật tương ứng nguồn và quy tắc mẻ cũ.
func honey_for(source: String, legacy: bool = false) -> ItemDefinition:
	return sunflower_honey if source == "sunflower" else floral_honey if (not source.is_empty() if legacy else is_rare_flower(source)) else wild_honey
