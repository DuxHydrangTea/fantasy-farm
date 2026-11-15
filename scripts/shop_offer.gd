class_name ShopOffer
extends Resource
## Một mặt hàng được hiển thị trong danh mục cửa hàng.

## Nhóm hiển thị và loại giao dịch của mặt hàng.
enum Category { CROP, FEED, FLOWER, ANIMAL, SELL_ANIMAL, UPGRADES, TOOLS }
## Vật phẩm gắn với lựa chọn trong cửa hàng.
@export var item: ItemDefinition
## Giá theo xu.
@export_range(1, 1000000) var price: int = 10
## Nhóm của lựa chọn trong giao diện cửa hàng.
@export var category: Category = Category.CROP
