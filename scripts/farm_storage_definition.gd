class_name FarmStorageDefinition
extends Resource
## Cấu hình kho và loại vật phẩm được phép cất trong kho.

## Kho nông sản và kho vật tư có quy tắc nhận vật phẩm riêng.
enum Kind { PRODUCE, SUPPLIES }
## Mã nhận diện kho.
@export var storage_id: StringName
## Tên kho hiển thị.
@export var display_name: String
## Nhóm kho quyết định quy tắc nhận vật phẩm.
@export var kind: Kind = Kind.PRODUCE
## Số ô lưu trữ.
@export_range(1, 512) var slot_count: int = 128
## Giới hạn số lượng mỗi chồng, giá trị 0 được chuyển cho hệ thống inventory.
@export_range(0, 32000) var stack_cap: int = 0

## Kiểm tra vật phẩm có mã hợp lệ và thuộc nhóm kho cho phép.
## Kho vật tư nhận thức ăn, hạt giống cây trồng hợp lệ và các booster
## phân bón, thuốc trừ sâu, thuốc thú y hoặc thuốc diệt cỏ.
func accepts(item: ItemDefinition) -> bool:
	if item == null or item.item_id.is_empty():
		return false
	if kind == Kind.PRODUCE:
		return item.item_type == ItemDefinition.ItemType.PRODUCE
	return item.item_type == ItemDefinition.ItemType.FEED or (item.item_type == ItemDefinition.ItemType.SEED and item.crop is CropDefinition and item.crop.is_valid()) or (item.item_type == ItemDefinition.ItemType.BOOSTER and item.booster_kind in [ItemDefinition.BoosterKind.FERTILIZER, ItemDefinition.BoosterKind.PESTICIDE, ItemDefinition.BoosterKind.ANIMAL_MEDICINE, ItemDefinition.BoosterKind.HERBICIDE])
