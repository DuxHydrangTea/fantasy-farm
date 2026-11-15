class_name WorkerUpgradeCatalog
extends Resource
## Bảng giá bằng xu cho các hướng nâng cấp công nhân.

## Giá các cấp tăng tốc.
@export var speed_prices: Array[int] = [10000, 15000, 22000, 32000, 45000, 60000, 80000, 105000, 135000, 170000]
## Giá nâng cấp cuốc.
@export var hoe_prices: Array[int] = [30000, 90000]
## Giá nâng cấp gieo hạt.
@export var sowing_prices: Array[int] = [40000, 120000]
## Giá nâng cấp tưới nước.
@export var watering_prices: Array[int] = [30000, 90000]
## Giá nâng cấp thu hoạch.
@export var harvest_prices: Array[int] = [50000, 150000]

## Lấy giá tiếp theo từ hướng và cấp hiện tại, trả về -1 khi hết mảng giá.
## Hướng tốc độ dùng cấp làm chỉ số, các hướng công cụ dùng cấp trừ một.
## Tên hướng khác các công cụ được liệt kê dùng bảng giá tốc độ.
func price(track: String, current: int) -> int:
	var prices: Array[int] = speed_prices
	match track:
		"hoe": prices = hoe_prices
		"sowing": prices = sowing_prices
		"watering": prices = watering_prices
		"harvest": prices = harvest_prices
	var index: int = current if track == "speed" else current - 1
	return prices[index] if index >= 0 and index < prices.size() else -1
