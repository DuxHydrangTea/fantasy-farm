class_name CropDefinition
extends Resource
## Dữ liệu dùng chung cho một loại cây trồng và sản phẩm thu hoạch.

## Mã nhận diện loại cây trồng.
@export var crop_id: StringName
## Bốn ảnh của các giai đoạn sinh trưởng.
@export var stage_textures: Array[Texture2D] = []
## Thời gian sinh trưởng tính bằng giây.
@export var growth_seconds: float = 1200.0
## Resource vật phẩm thu hoạch, được kiểm tra riêng bởi [method has_valid_harvest].
@export var harvest_item: Resource
## Số lượng vật phẩm thu được.
@export var harvest_amount: int = 1

## Kiểm tra thời gian dương và đủ bốn ảnh giai đoạn khác null.
func is_valid() -> bool:
	return growth_seconds > 0.0 and stage_textures.size() == 4 and not stage_textures.has(null)

## Kiểm tra sản phẩm là ItemDefinition loại nông sản và số lượng dương.
func has_valid_harvest() -> bool:
	return harvest_item is ItemDefinition and harvest_item.item_type == ItemDefinition.ItemType.PRODUCE and harvest_amount > 0
