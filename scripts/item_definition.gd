class_name ItemDefinition
extends Resource
## Định nghĩa dùng chung của một loại vật phẩm trong inventory.
##
## Các trường chuyên biệt cho công cụ, hạt giống, thức ăn và booster được
## diễn giải theo [member item_type] bởi hệ thống sử dụng vật phẩm.

## Nhóm vật phẩm dùng để phân loại và kiểm tra hành động.
enum ItemType { TOOL, SEED, PRODUCE, FEED, HOE, BOOSTER, PLACEABLE, MATERIAL }
## Công dụng của vật phẩm thuộc nhóm booster.
enum BoosterKind { FERTILIZER, ANIMAL_TONIC, ROOT_TONIC, PESTICIDE, ANIMAL_MEDICINE, HERBICIDE }
## Loại công cụ có thể trang bị hoặc sử dụng.
enum ToolType { HOE, WATERING_CAN, AXE }

## Mã ổn định dùng để so sánh vật phẩm và lưu dữ liệu.
@export var item_id: StringName
## Đánh dấu biến thể quả chất lượng sao.
@export var star_fruit: bool = false
## Tên hiển thị.
@export var display_name: String
## Mô tả hiển thị.
@export_multiline var description: String
## Loại booster khi vật phẩm thuộc nhóm BOOSTER.
@export var booster_kind: BoosterKind = BoosterKind.FERTILIZER
## Biểu tượng hiển thị.
@export var icon: Texture2D
## Cho phép hiển thị số lượng cạnh vật phẩm trong thế giới.
@export var show_world_quantity: bool = true
## Nhóm của vật phẩm.
@export var item_type: ItemType = ItemType.TOOL
## Loại công cụ khi vật phẩm là công cụ.
@export var tool_type: ToolType = ToolType.HOE
## Định nghĩa cây trồng liên quan đến hạt giống, nếu có.
@export var crop: Resource
## Số lượng tối đa một chồng đối với vật phẩm có thể xếp chồng.
@export_range(1, 32000) var max_stack: int = 99
## Số đơn vị thức ăn được cung cấp bởi một vật phẩm thức ăn.
@export_range(1, 32000) var food_units_per_item: int = 300

## Trả về 1 cho công cụ và cuốc, còn lại dùng max_stack với tối thiểu là 1.
func get_stack_limit() -> int:
	return 1 if item_type == ItemType.TOOL or item_type == ItemType.HOE else maxi(1, max_stack)

## Kiểm tra resource khác là ItemDefinition có cùng mã không rỗng.
func matches(other: Resource) -> bool:
	return other is ItemDefinition and not item_id.is_empty() and item_id == other.item_id
