class_name WorkerUpgradeState
extends RefCounted
## Profile-owned progress, independent of employment and player tools.
const TRACKS: Array[String] = ["speed", "hoe", "sowing", "watering", "harvest"]
var levels: Dictionary = fresh()

static func fresh() -> Dictionary:
	return {"speed": 0, "hoe": 1, "sowing": 1, "watering": 1, "harvest": 1}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != TRACKS.size():
		return false
	for track: String in TRACKS:
		if not SaveSchema.number(data.get(track), 0 if track == "speed" else 1, maximum(track), true):
			return false
	return true

static func maximum(track: String) -> int:
	return 10 if track == "speed" else 3

func level(track: String) -> int:
	return int(levels.get(track, 0))

func duration(base: float, kind: String) -> float:
	return base if kind == "patrol" else base * pow(0.9, level("speed"))
