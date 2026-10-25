class_name WoodMarket
extends RefCounted
## Shared profile stock. Quotes are read-only; only successful purchases spend it.
const ITEM: StringName = &"wood"
const DAILY_CAP: int = 30
const LEGACY_SELL_PRICE: int = 25
const BUY_PRICE: int = 63 # round(25 * 2.5), integer coins.
var day: int = -1000000000
var bought: int = 0
var busy: bool = false

static func fresh() -> Dictionary:
	return {"day": -1000000000, "bought": 0}

func used(now: float) -> int:
	return 0 if WeatherSchedule.new().day_at(now) > day else bought

func remaining(now: float) -> int:
	return DAILY_CAP - used(now)

func spend(amount: int, now: float) -> bool:
	if not busy or amount < 1 or amount > remaining(now):
		return false
	var today: int = WeatherSchedule.new().day_at(now)
	if today > day:
		day = today
		bought = 0
	bought += amount
	return true

func capture(now: float) -> Dictionary:
	return {"day": maxi(day, WeatherSchedule.new().day_at(now)), "bought": used(now)}

func restore(data: Dictionary) -> void:
	day = int(data.day)
	bought = int(data.bought)

static func valid(data: Variant, saved_at: float) -> bool:
	return data is Dictionary and data.size() == 2 and SaveSchema.number(data.get("day"), -1000000000, WeatherSchedule.new().day_at(saved_at), true) and SaveSchema.number(data.get("bought"), 0, DAILY_CAP, true)
