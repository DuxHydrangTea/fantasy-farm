class_name WeatherSchedule
extends RefCounted
## Tính thời tiết theo ngày và các lần thay đổi thủ công có mốc thời gian.
##
## Ngày thời tiết bắt đầu lúc 06:00 theo múi giờ UTC+7. Kết quả mặc định
## phụ thuộc vào ngày và [member seed], nhờ đó có thể tính lại khi mô phỏng
## thời gian offline mà không phụ thuộc trạng thái bộ sinh số ngẫu nhiên.

## Các trạng thái thời tiết được lịch hỗ trợ.
enum Weather { SUNNY, RAIN, CLOUDY, WINDY }
## Độ dài một ngày tính bằng giây.
const DAY: float = 86400.0
## Độ lệch UTC+7 tính bằng giây.
const UTC_OFFSET: float = 25200.0
## Thời điểm bắt đầu ngày thời tiết theo giờ địa phương, tính từ nửa đêm.
const DAWN: float = 21600.0
## Giá trị kết hợp với số ngày để chọn thời tiết mặc định.
var seed: int = 0
## Danh sách thay đổi thủ công gồm các trường [code]at[/code] và [code]weather[/code].
## Các bản ghi cần được sắp theo thời gian tăng dần.
var changes: Array[Dictionary] = []

## Trả về chỉ số ngày thời tiết chứa timestamp tính bằng giây.
func day_at(timestamp: float) -> int:
	return floori((timestamp + UTC_OFFSET - DAWN) / DAY)

## Trả về timestamp của bình minh bắt đầu ngày có chỉ số [param day].
func dawn_at(day: int) -> float:
	return day * DAY - UTC_OFFSET + DAWN

## Trả về thời tiết tại [param timestamp].
## Thay đổi thủ công gần nhất trong cùng ngày được ưu tiên. Nếu không có,
## lịch chọn nắng 60%, mưa 20%, nhiều mây 10% và gió 10% theo ngày và seed.
func weather_at(timestamp: float) -> Weather:
	var day: int = day_at(timestamp)
	for index: int in range(changes.size() - 1, -1, -1):
		var entry: Dictionary = changes[index]
		if float(entry.at) <= timestamp and day_at(float(entry.at)) == day:
			return int(entry.weather) as Weather
	# Integer mixing makes reloads and offline queries independent of global RNG.
	var roll: int = posmod((day + seed) * 1103515245 + 12345, 2147483647) % 100
	return Weather.SUNNY if roll < 60 else Weather.RAIN if roll < 80 else Weather.CLOUDY if roll < 90 else Weather.WINDY

## Trả về bình minh kế tiếp hoặc mốc thay đổi thủ công gần nhất sau thời điểm này.
## Các mốc cách thời điểm truy vấn không quá một micro giây được bỏ qua.
func next_boundary(timestamp: float) -> float:
	var result: float = dawn_at(day_at(timestamp) + 1)
	for entry: Dictionary in changes:
		if float(entry.at) > timestamp + 0.000001:
			result = minf(result, float(entry.at))
	return result

## Hệ số nước tại thời điểm truy vấn, bằng 0,75 khi nhiều mây và 1 ở các trạng thái khác.
func water_rate(timestamp: float) -> float:
	return 0.75 if weather_at(timestamp) == Weather.CLOUDY else 1.0

## Hệ số bay hơi, bằng 0 khi mưa, 0,75 khi nhiều mây và 1 ở các trạng thái khác.
func evaporation_rate(timestamp: float) -> float:
	var weather: Weather = weather_at(timestamp)
	return 0.0 if weather == Weather.RAIN else 0.75 if weather == Weather.CLOUDY else 1.0

## Hệ số bán kính, bằng 1,5 khi có gió và 1 ở các trạng thái khác.
func radius_multiplier(timestamp: float) -> float:
	return 1.5 if weather_at(timestamp) == Weather.WINDY else 1.0

## Tạo dữ liệu lưu gồm seed và bản sao sâu của danh sách thay đổi.
func capture() -> Dictionary:
	return {"seed": seed, "changes": changes.duplicate(true)}

## Khôi phục seed và thay thế danh sách thay đổi từ dữ liệu đã được kiểm tra.
## Mỗi bản ghi đầu vào phải chứa các trường mà [method weather_at] sử dụng.
func restore(data: Dictionary) -> void:
	seed = int(data.seed)
	changes.clear()
	for entry: Dictionary in data.changes:
		changes.append(entry.duplicate())
