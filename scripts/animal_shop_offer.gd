class_name AnimalShopOffer
extends Resource
@export var animal: AnimalDefinition
@export_range(1, 1000000) var price: int = 160

func is_valid() -> bool:
	return animal != null and animal.is_valid() and price > 0 and price <= 1000000

func resale_price(adult: bool) -> int:
	return maxi(1, floori(price * (0.75 if adult else 0.5)))

func icon() -> Texture2D:
	return animal.adult_frames.get_frame_texture(&"idle_down", 0) if is_valid() else null
