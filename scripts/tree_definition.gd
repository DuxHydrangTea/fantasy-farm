class_name TreeDefinition
extends Resource
## Dữ liệu dùng chung của một loại cây; trạng thái từng cây được lưu riêng.

## Nhóm cây ăn quả hoặc cây lấy gỗ.
enum Kind { FRUIT, TIMBER }
## Mã ổn định của loại cây.
@export var tree_id: StringName
## Tên hiển thị.
@export var display_name: String
## Nhóm cây quyết định các tài nguyên cần thiết.
@export var kind: Kind = Kind.FRUIT
## Thời gian sinh trưởng tính bằng giây.
@export var growth_seconds: float = 180.0
## Thời gian giữa các chu kỳ tạo quả, tính bằng giây.
@export var fruit_cycle_seconds: float = 90.0
## Thời gian liên quan đến gốc cây, tính bằng giây.
@export var stump_seconds: float = 120.0
## Số nhát chặt cần thiết.
@export var chop_hits: int = 4
## Số lần đào cần thiết.
@export var dig_hits: int = 1
## Số lượng sản phẩm thu hoạch.
@export var harvest_amount: int = 3
## Sản phẩm chất lượng sao.
@export var star_harvest_item: ItemDefinition
## Sản phẩm thu hoạch thông thường.
@export var harvest_item: ItemDefinition
## Vật phẩm liên quan đến gốc hoặc rễ cây.
@export var root_item: ItemDefinition
## Ba ảnh cho các giai đoạn sinh trưởng.
@export var stage_textures: Array[Texture2D] = []
## Ảnh cây sẵn sàng thu hoạch.
@export var ready_texture: Texture2D
## Ảnh gốc cây sau khi chặt.
@export var stump_texture: Texture2D
## Ảnh tán cây.
@export var canopy_texture: Texture2D
## Ảnh lá.
@export var leaf_texture: Texture2D

## Tải vật phẩm cây giống theo quy ước đường dẫn từ [member tree_id].
## Trả về null nếu resource không tải được hoặc không phải ItemDefinition.
func planting_item() -> ItemDefinition:
	var path: String = "res://items/trees/%s_sapling.tres" % tree_id
	return load(path) as ItemDefinition

## Kiểm tra mã, các thời gian và số lần thao tác dương, sản phẩm và ảnh cần thiết.
## Cây lấy gỗ còn cần vật phẩm rễ, ảnh gốc và ảnh tán.
func is_valid() -> bool:
	return not tree_id.is_empty() and growth_seconds > 0.0 and fruit_cycle_seconds > 0.0 and stump_seconds > 0.0 and chop_hits > 0 and dig_hits > 0 and harvest_amount > 0 and harvest_item != null and stage_textures.size() == 3 and not stage_textures.has(null) and ready_texture != null and (kind == Kind.FRUIT or (root_item != null and stump_texture != null and canopy_texture != null))
