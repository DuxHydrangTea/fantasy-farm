class_name FlowerDefinition
extends Resource
## Dữ liệu dùng chung của một loài hoa, gồm năm ảnh theo giai đoạn sinh trưởng.

## Mã ổn định của loài hoa.
@export var flower_id: StringName
## Tên hiển thị.
@export var display_name: String
## Năm ảnh tương ứng năm giai đoạn phát triển.
@export var stage_textures: Array[Texture2D] = []
## Thời gian sinh trưởng tính bằng giây.
@export_range(1.0, 86400.0) var growth_seconds: float = 120.0
## Vật phẩm thu được.
@export var harvest_item: ItemDefinition
## Số lượng thu được.
@export_range(1, 99) var harvest_amount: int = 1

## Kiểm tra mã, thời gian, đủ năm ảnh khác null và vật phẩm thu hoạch.
func is_valid() -> bool:
	return not flower_id.is_empty() and growth_seconds > 0.0 and stage_textures.size() == 5 and not stage_textures.has(null) and harvest_item != null
