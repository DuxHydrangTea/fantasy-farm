class_name AnimalShopOffer
extends Resource
## Một lựa chọn mua vật nuôi và quy tắc tính giá bán lại.

## Định nghĩa vật nuôi được giao dịch.
@export var animal: AnimalDefinition
## Giá mua bằng xu.
@export_range(1, 1000000) var price: int = 160

## Kiểm tra định nghĩa vật nuôi hợp lệ và giá trong khoảng 1–1.000.000 xu.
func is_valid() -> bool:
	return animal != null and animal.is_valid() and price > 0 and price <= 1000000

## Giá bán lại bằng 75% giá mua cho con trưởng thành, 50% cho con non.
## Giá được làm tròn xuống và luôn ít nhất một xu.
func resale_price(adult: bool) -> int:
	return maxi(1, floori(price * (0.75 if adult else 0.5)))

## Lấy khung đầu của hoạt ảnh đứng nhìn xuống khi dữ liệu hợp lệ, nếu không trả null.
func icon() -> Texture2D:
	return animal.adult_frames.get_frame_texture(&"idle_down", 0) if is_valid() else null
