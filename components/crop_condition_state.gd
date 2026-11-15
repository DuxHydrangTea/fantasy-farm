extends RefCounted
## Trạng thái sâu bệnh và cỏ dại của một cây trồng.
## Các giá trị ngẫu nhiên được chọn khi tạo và lưu lại để mô phỏng, tải lại
## hoặc tính sản lượng nhiều lần đều cho cùng kết quả.

## Cấu hình xác suất và hệ số năng suất.
const RULES: Resource = preload("res://resources/farm_health_rules.tres")
## Cây hiện bị sâu bệnh.
var pests: bool = false
## Cây hiện có cỏ dại.
var weeds: bool = false
## Mốc kiểm tra sâu bệnh đã được xử lý.
var pest_checked: bool = false
## Mốc kiểm tra cỏ dại đã được xử lý.
var weed_checked: bool = false
## Giá trị ngẫu nhiên dùng ở mốc sâu bệnh.
var pest_roll: float = 0.5
## Giá trị ngẫu nhiên dùng ở mốc cỏ dại.
var weed_roll: float = 0.5
## Giá trị dùng để làm tròn sản lượng kỳ vọng.
var yield_roll: float = 0.5

## Đặt trạng thái sạch và chọn các giá trị ngẫu nhiên cho cây mới.
func configure() -> void:
	pests = false
	weeds = false
	pest_checked = false
	weed_checked = false
	pest_roll = randf()
	weed_roll = randf()
	yield_roll = randf()

## Kiểm tra sâu bệnh tại một phần ba và cỏ dại tại hai phần ba tiến độ.
## Mỗi mốc chỉ được xét một lần.
func advance(progress: float) -> void:
	if not pest_checked and progress >= 1.0 / 3.0:
		pest_checked = true
		pests = pest_roll < RULES.pest_chance
	if not weed_checked and progress >= 2.0 / 3.0:
		weed_checked = true
		weeds = weed_roll < RULES.weed_chance

## Cho biết cây đang bị ít nhất một tình trạng bất lợi.
func affected() -> bool:
	return pests or weeds

## Tích hệ số năng suất của các tình trạng đang có.
func multiplier() -> float:
	return (float(RULES.pest_yield) if pests else 1.0) * (float(RULES.weed_yield) if weeds else 1.0)

## Tính sản lượng từ giá trị cơ sở và làm tròn xác suất bằng yield_roll đã lưu.
func amount(base: int) -> int:
	var expected: float = base * multiplier()
	return floori(expected) + (1 if yield_roll < expected - floorf(expected) else 0)

## Chụp các cờ và giá trị ngẫu nhiên để lưu.
func capture() -> Dictionary:
	return {"pests": pests, "weeds": weeds, "pest_checked": pest_checked, "weed_checked": weed_checked, "pest_roll": pest_roll, "weed_roll": weed_roll, "yield_roll": yield_roll}

## Khôi phục trạng thái từ dữ liệu đã được kiểm tra.
func restore(data: Dictionary) -> void:
	pests = data.pests
	weeds = data.weeds
	pest_checked = data.pest_checked
	weed_checked = data.weed_checked
	pest_roll = data.pest_roll
	weed_roll = data.weed_roll
	yield_roll = data.yield_roll

## Tạo trạng thái sạch cho cây cũ và đánh dấu cả hai mốc đã kiểm tra.
static func legacy() -> Dictionary:
	# Existing crops get a clean protected first harvest, without rolling on load.
	return {"pests": false, "weeds": false, "pest_checked": true, "weed_checked": true, "pest_roll": 0.5, "weed_roll": 0.5, "yield_roll": 0.5}

## Kiểm tra bảy trường, miền số ngẫu nhiên và tính nhất quán của cờ kiểm tra.
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
