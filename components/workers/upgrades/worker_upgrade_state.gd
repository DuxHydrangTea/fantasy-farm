class_name WorkerUpgradeState
extends RefCounted
## Cấp nâng cấp công nhân thuộc profile, độc lập với việc thuê và công cụ người chơi.

## Các hướng nâng cấp được lưu.
const TRACKS: Array[String] = ["speed", "hoe", "sowing", "watering", "harvest"]
## Ánh xạ mã hướng nâng cấp sang cấp hiện tại.
var levels: Dictionary = fresh()

## Tạo cấp mặc định: tốc độ 0 và các công cụ cấp 1.
static func fresh() -> Dictionary:
	return {"speed": 0, "hoe": 1, "sowing": 1, "watering": 1, "harvest": 1}

## Kiểm tra đủ các hướng và cấp nguyên trong giới hạn của từng hướng.
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != TRACKS.size():
		return false
	for track: String in TRACKS:
		if not SaveSchema.number(data.get(track), 0 if track == "speed" else 1, maximum(track), true):
			return false
	return true

## Cấp tối đa là 10 cho tốc độ và 3 cho các hướng còn lại.
static func maximum(track: String) -> int:
	return 10 if track == "speed" else 3

## Lấy cấp hiện tại, trả 0 nếu không có hướng trong bảng.
func level(track: String) -> int:
	return int(levels.get(track, 0))

## Tính thời gian thao tác sau nâng cấp tốc độ. Tuần tra giữ thời gian cơ sở;
## các việc khác nhân với 0,9 lũy thừa cấp tốc độ.
func duration(base: float, kind: String) -> float:
	return base if kind == "patrol" else base * pow(0.9, level("speed"))
