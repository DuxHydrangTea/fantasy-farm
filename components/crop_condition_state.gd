extends RefCounted
const RULES: Resource = preload("res://resources/farm_health_rules.tres")
var pests: bool = false
var weeds: bool = false
var pest_checked: bool = false
var weed_checked: bool = false
var pest_roll: float = 0.5
var weed_roll: float = 0.5
var yield_roll: float = 0.5

func configure() -> void:
	pests = false
	weeds = false
	pest_checked = false
	weed_checked = false
	pest_roll = randf()
	weed_roll = randf()
	yield_roll = randf()

func advance(progress: float) -> void:
	if not pest_checked and progress >= 1.0 / 3.0:
		pest_checked = true
		pests = pest_roll < RULES.pest_chance
	if not weed_checked and progress >= 2.0 / 3.0:
		weed_checked = true
		weeds = weed_roll < RULES.weed_chance

func affected() -> bool:
	return pests or weeds

func multiplier() -> float:
	return (float(RULES.pest_yield) if pests else 1.0) * (float(RULES.weed_yield) if weeds else 1.0)

func amount(base: int) -> int:
	var expected: float = base * multiplier()
	return floori(expected) + (1 if yield_roll < expected - floorf(expected) else 0)

func capture() -> Dictionary:
	return {"pests": pests, "weeds": weeds, "pest_checked": pest_checked, "weed_checked": weed_checked, "pest_roll": pest_roll, "weed_roll": weed_roll, "yield_roll": yield_roll}

func restore(data: Dictionary) -> void:
	pests = data.pests
	weeds = data.weeds
	pest_checked = data.pest_checked
	weed_checked = data.weed_checked
	pest_roll = data.pest_roll
	weed_roll = data.weed_roll
	yield_roll = data.yield_roll

static func legacy() -> Dictionary:
	# Existing crops get a clean protected first harvest, without rolling on load.
	return {"pests": false, "weeds": false, "pest_checked": true, "weed_checked": true, "pest_roll": 0.5, "weed_roll": 0.5, "yield_roll": 0.5}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 7:
		return false
	for key: String in ["pests", "weeds", "pest_checked", "weed_checked"]:
		if not data.get(key) is bool:
			return false
	for key: String in ["pest_roll", "weed_roll", "yield_roll"]:
		if not SaveSchema.number(data.get(key), 0, 1):
			return false
	return (not data.pests or data.pest_checked) and (not data.weeds or data.weed_checked)
