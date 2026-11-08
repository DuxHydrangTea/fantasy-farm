class_name WorkerUpgradeCatalog
extends Resource
## Coin-only offers, separate from player tool upgrades.
@export var speed_prices: Array[int] = [10000, 15000, 22000, 32000, 45000, 60000, 80000, 105000, 135000, 170000]
@export var hoe_prices: Array[int] = [30000, 90000]
@export var sowing_prices: Array[int] = [40000, 120000]
@export var watering_prices: Array[int] = [30000, 90000]
@export var harvest_prices: Array[int] = [50000, 150000]

func price(track: String, current: int) -> int:
	var prices: Array[int] = speed_prices
	match track:
		"hoe": prices = hoe_prices
		"sowing": prices = sowing_prices
		"watering": prices = watering_prices
		"harvest": prices = harvest_prices
	var index: int = current if track == "speed" else current - 1
	return prices[index] if index >= 0 and index < prices.size() else -1
