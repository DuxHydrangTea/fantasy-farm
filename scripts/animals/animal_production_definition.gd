class_name AnimalProductionDefinition
extends Resource
## Cấu hình sản phẩm và chu kỳ tạo sản phẩm của vật nuôi.
## Tên class được giữ để các resource sản xuất hiện có tiếp tục tham chiếu.

## Phương thức nhận sản phẩm, thả ra thế giới hoặc thu trực tiếp.
enum CollectionMode { WORLD_DROP, DIRECT_COLLECTION }
## Vật phẩm nông sản được tạo ra.
@export var production_item: ItemDefinition
## Số đơn vị tạo ra trong mỗi chu kỳ.
@export_range(1, 32000) var production_amount: int = 1
## Thời gian một chu kỳ tính bằng giây.
@export_range(1.0, 86400.0) var production_seconds: float = 1.0
## Cách người chơi nhận sản phẩm.
@export var collection_mode: CollectionMode = CollectionMode.WORLD_DROP

## Kiểm tra vật phẩm là nông sản và số lượng, thời gian đều dương.
func is_valid() -> bool:
	return production_item != null and production_item.item_type == ItemDefinition.ItemType.PRODUCE and production_amount > 0 and production_seconds > 0.0
