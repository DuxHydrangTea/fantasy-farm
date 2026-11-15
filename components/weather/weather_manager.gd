class_name WeatherManager
extends Node
## Điều phối thời tiết của trang trại và tác động của nó theo thời gian mô phỏng.
## Hiệu ứng chuyển màu chỉ thay đổi hiển thị; thời gian mô phỏng do đồng hồ quản lý.

## Tên enum thời tiết dùng chung từ lịch.
const Weather = WeatherSchedule.Weather
## Phát khi trạng thái thời tiết hiện tại thay đổi.
signal weather_changed(weather: int)
## Thế giới chịu tác động thời tiết.
var world: FarmWorld
## Lịch thời tiết xác định và các lần thay đổi thủ công.
var schedule: WeatherSchedule = WeatherSchedule.new()
## Thời tiết đã áp dụng gần nhất.
var current_weather: WeatherSchedule.Weather = Weather.SUNNY
## Điều khiển ánh sáng ngày đêm.
var day_night: DayNightComponent
## Điều khiển hiệu ứng thời tiết.
var effects: WeatherEffects
## Giao diện đồng hồ và thời tiết.
var hud: WeatherHUD
## Mốc mô phỏng đã xử lý gần nhất.
var last_at: float = 0.0
## Giờ xem thử ánh sáng trong bản debug; -1 dùng thời gian thực của mô phỏng.
var debug_hour: int = -1
var _rain_day: int = -9223372036854775807
var _rain_columns: int = -1
var _advancing: bool = false

func _ready() -> void:
	last_at = world.farming.time_manager.now()
	day_night = DayNightComponent.new()
	day_night.world = world
	add_child(day_night)
	effects = WeatherEffects.new()
	effects.world = world
	add_child(effects)
	hud = WeatherHUD.new()
	hud.manager = self
	add_child(hud)
	world.farming.time_manager.tick.connect(advance)
	advance(last_at)

## Tiến thời tiết đến mốc yêu cầu, không lùi trước [member last_at].
## Chia khoảng tại ranh giới thời tiết để tính bay hơi đất, áp dụng mưa,
## cập nhật hiệu ứng và phát signal khi thời tiết đổi.
func advance(timestamp: float, refresh_visuals: bool = true) -> void:
	if _advancing:
		return
	_advancing = true
	timestamp = maxf(last_at, timestamp)
	var cursor: float = last_at
	_apply_rain(cursor)
	while cursor < timestamp - 0.000001:
		var boundary: float = minf(timestamp, schedule.next_boundary(cursor))
		world.farming.evaporate_soil((boundary - cursor) * schedule.evaporation_rate(cursor))
		cursor = boundary
		_apply_rain(cursor)
	last_at = timestamp
	var next: WeatherSchedule.Weather = schedule.weather_at(timestamp)
	if next != current_weather:
		current_weather = next
		effects.transition_to(next)
		weather_changed.emit(next)
	if refresh_visuals:
		day_night.refresh(display_timestamp(timestamp), effects.weather_tint())
		hud.refresh(display_timestamp(timestamp))
	_advancing = false

func _apply_rain(timestamp: float) -> void:
	var columns: int = world.farming.land.unlocked_blocks
	var day: int = schedule.day_at(timestamp)
	if schedule.weather_at(timestamp) == Weather.RAIN and (day != _rain_day or columns != _rain_columns):
		_rain_day = day
		_rain_columns = columns
		world.farming.rain_water()

## Đổi thời tiết thủ công cho phần còn lại của ngày hiện tại.
## Chốt tác động của khoảng cũ lên đất, đàn ong và vật nuôi trước khi ghi
## mốc thay đổi, sau đó cập nhật hiệu ứng tại cùng thời điểm.
func set_weather(next_weather: WeatherSchedule.Weather) -> void:
	if _advancing or next_weather < Weather.SUNNY or next_weather > Weather.WINDY:
		return
	var timestamp: float = world.farming.time_manager.now()
	if next_weather == schedule.weather_at(timestamp):
		return
	# Commit the old interval before replacing its weather. Overrides affect only
	# the rest of this day; reloading never applies today's weather to yesterday.
	advance(timestamp)
	world.apiary.advance(timestamp)
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		var animal: AnimalActor = node as AnimalActor
		if world.is_ancestor_of(animal):
			animal.needs.update_at(timestamp)
	schedule.changes.append({"at": timestamp, "weather": int(next_weather)})
	_rain_day = -9223372036854775807
	advance(timestamp)
	world.apiary.advance(timestamp)

## Khôi phục lịch đã kiểm tra và đặt lại mốc xử lý cùng cache tưới mưa.
func restore(data: Dictionary, timestamp: float) -> void:
	schedule.restore(data)
	last_at = timestamp
	_rain_day = -9223372036854775807
	_rain_columns = -1

## Trả thời điểm dùng để hiển thị, thay giờ bằng giờ xem thử nếu debug đang bật.
func display_timestamp(timestamp: float) -> float:
	if debug_hour < 0:
		return timestamp
	return timestamp - fposmod(timestamp + WeatherSchedule.UTC_OFFSET, 86400.0) + debug_hour * 3600.0

## Đặt giờ xem thử từ 0 đến 23 hoặc -1 để tắt, chỉ áp dụng trong bản debug.
func set_debug_hour(hour: int) -> void:
	if not OS.is_debug_build() or hour < -1 or hour > 23:
		return
	debug_hour = hour
	day_night.refresh(display_timestamp(last_at), effects.weather_tint())
	hud.refresh(display_timestamp(last_at))

func _process(_delta: float) -> void:
	if day_night != null:
		day_night.refresh(display_timestamp(last_at), effects.weather_tint())
