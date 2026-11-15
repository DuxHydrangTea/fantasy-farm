class_name ShopCatalog
extends Resource
## Dữ liệu hiển thị cửa hàng và các danh sách hàng bán.

## Tên cửa hàng hiển thị cho người chơi.
@export var display_name: String = "LAI BUON'S SHOP"
## Các mã danh mục được hiển thị.
@export var category_ids: Array[int] = [0, 1, 2, 3, 4, 5]
## Các lựa chọn mua vật phẩm.
@export var offers: Array[ShopOffer] = []
## Các lựa chọn mua vật nuôi.
@export var animal_offers: Array[AnimalShopOffer] = []
