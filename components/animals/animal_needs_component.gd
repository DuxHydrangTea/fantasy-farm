class_name AnimalNeedsComponent
extends Node

signal changed(satiety: float, hydration: float)
## Eligible time is measured BEFORE depletion, including partial last intervals.
signal time_advanced(timestamp: float, elapsed: float, supplied_seconds: float)
@export var time_manager: FarmClock
var satiety: float = 100.0
var hydration: float = 100.0
var satiety_depletion_seconds: float = 600.0
var hydration_depletion_seconds: float = 600.0
var _updated_at: float = 0.0
var _active: bool = true
var weather: WeatherSchedule
var pen: AnimalPen

func updated_at() -> float:
	return _updated_at

func apply_offline_step(timestamp: float, elapsed: float, supplied: float, food: float, water: float) -> void:
	if not _active:
		return
	_updated_at = timestamp
	_set_values(food, water)
	time_advanced.emit(timestamp, elapsed, supplied)

func _ready() -> void:
	if time_manager == null:
		time_manager = TimeManager
	if time_manager != null:
		_updated_at = time_manager.now()
		time_manager.tick.connect(update_at)

func configure(food_seconds: float, water_seconds: float) -> void:
	satiety_depletion_seconds = maxf(1.0, food_seconds)
	hydration_depletion_seconds = maxf(1.0, water_seconds)

## Set a baseline without crediting the interval twice; update_at applies catch-up.
func restore_state(food: float, water: float, timestamp: float) -> void:
	_updated_at = timestamp
	_set_values(food, water)

# TÍNH NO/KHÁT THEO THỜI GIAN THỰC — dùng cả lúc chơi và bắt kịp sau offline.
# elapsed = max(0, giờ mới - mốc cũ) ngăn thời gian lùi làm vật nuôi được cộng no/nước.
# Nếu 100% no hết trong D giây, còn p% thì còn p*D/100 giây được cung cấp thức ăn.
# Thời gian được sản xuất chỉ là min(elapsed, giây còn no, giây còn nước), tính TRƯỚC khi trừ.
# Ví dụ offline 600 giây nhưng nước chỉ đủ 60 giây: chỉ 60 giây được xét sinh sản phẩm.
# Nếu bỏ giới hạn này, vật nuôi đói/khát vẫn tạo sản phẩm suốt thời gian offline.
# Nếu tính sau khi trừ no/nước, khoảng cuối vừa hết nước có thể mất phần sản xuất hợp lệ.
func update_at(timestamp: float) -> void:
	if not _active:
		return
	if pen != null and timestamp - _updated_at > PenOfflineSimulation.SUSPENSION_GAP and pen.advance_offline(timestamp):
		return
	while _active and _updated_at < timestamp - 0.000001:
		var end: float = minf(timestamp, weather.next_boundary(_updated_at)) if weather != null else timestamp
		var elapsed: float = end - _updated_at
		var water_rate: float = weather.water_rate(_updated_at) if weather != null else 1.0
		var food_seconds: float = satiety * satiety_depletion_seconds / 100.0
		var water_seconds: float = hydration * hydration_depletion_seconds / (100.0 * water_rate)
		var supplied: float = minf(elapsed, minf(food_seconds, water_seconds))
		_updated_at = end
		_set_values(satiety - elapsed * 100.0 / satiety_depletion_seconds, hydration - elapsed * water_rate * 100.0 / hydration_depletion_seconds)
		time_advanced.emit(end, elapsed, supplied)

func feed(amount: float) -> float:
	_sync()
	if not _active:
		return 0.0
	var before: float = satiety
	_set_values(satiety + maxf(0.0, amount), hydration)
	return satiety - before

func drink(amount: float) -> float:
	_sync()
	if not _active:
		return 0.0
	var before: float = hydration
	_set_values(satiety, hydration + maxf(0.0, amount))
	return hydration - before

## Prevent a late trough callback from feeding an actor retired during _sync().
func deactivate() -> void:
	_active = false

# Chốt phần thời gian cũ trước khi cho ăn/uống. Nếu cộng no trước rồi mới tính elapsed,
# thức ăn vừa đổ vào có thể bị xem như đã có trong cả khoảng offline đã qua và sinh thưởng ngược.
# Đây là yêu cầu giữ đúng thứ tự thời gian, không phải một hiệu ứng có thể bỏ tùy ý.
func _sync() -> void:
	if time_manager != null:
		update_at(time_manager.now())

func _set_values(food: float, water: float) -> void:
	var next_food: float = clampf(food, 0.0, 100.0)
	var next_water: float = clampf(water, 0.0, 100.0)
	if is_equal_approx(next_food, satiety) and is_equal_approx(next_water, hydration):
		return
	satiety = next_food
	hydration = next_water
	changed.emit(satiety, hydration)
