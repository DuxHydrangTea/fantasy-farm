extends RefCounted
## Trạng thái bệnh của một vật nuôi và lịch phát bệnh có thể lưu, khôi phục.
## Mốc phát bệnh được lấy mẫu một lần để tính nhanh cả khoảng offline dài.

## Cấu hình xác suất, chu kỳ kiểm tra và hệ số sản xuất khi bệnh.
const RULES: Resource = preload("res://resources/farm_health_rules.tres")
## Cho biết vật nuôi đang bệnh.
var sick: bool = false
## Timestamp dự kiến phát bệnh.
var next_onset_at: float = 0.0
## Trạng thái bộ sinh số dùng để lập lịch bệnh tiếp theo.
var rng_state: int = 1

## Khởi tạo trạng thái khỏe và lập lịch bệnh sau tuổi non và thời gian bảo vệ.
## Seed được chuẩn hóa vào miền trạng thái bộ sinh số.
func configure(timestamp: float, juvenile_seconds: float = 0.0, seed_value: int = 1) -> void:
	sick = false
	rng_state = posmod(seed_value, 2147483646) + 1
	_schedule(timestamp + maxf(0.0, juvenile_seconds) + float(RULES.protection_seconds))

func _schedule(protected_until: float) -> void:
	# Sample the geometric waiting time once: equivalent to independent periodic
	# checks, but bounded O(1) even after a very long suspension. Persist the result.
	rng_state = (rng_state * 48271) % 2147483647
	var roll: float = float(rng_state) / 2147483647.0
	var checks: int = maxi(1, ceili(log(1.0 - roll) / log(1.0 - float(RULES.disease_chance))))
	next_onset_at = protected_until + checks * float(RULES.disease_check_seconds)

## Tính số giây sản xuất hiệu dụng trong giao của hai khoảng đầu vào.
## Phần thời gian bị bệnh được nhân hệ số sản xuất khi bệnh. Nếu khoảng đi
## qua mốc phát bệnh, trạng thái chuyển sang bệnh ngay cả khi giao rỗng.
func advance(start: float, end: float, eligible_start: float, eligible_end: float) -> float:
	var first: float = maxf(start, eligible_start)
	var last: float = minf(end, eligible_end)
	var duration: float = maxf(0.0, last - first)
	var effective: float = duration * float(RULES.sick_production_rate) if sick else duration
	if not sick and end >= next_onset_at:
		var sick_seconds: float = maxf(0.0, last - maxf(first, next_onset_at))
		effective -= sick_seconds * (1.0 - float(RULES.sick_production_rate))
		sick = true
	return effective

## Chữa bệnh và lập lịch phát bệnh mới sau thời gian bảo vệ.
## Trả về false nếu vật nuôi đang khỏe.
func cure(timestamp: float) -> bool:
	if not sick:
		return false
	sick = false
	_schedule(timestamp + float(RULES.protection_seconds))
	return true

## Tạo dữ liệu lưu gồm trạng thái bệnh, mốc phát bệnh và trạng thái RNG.
func capture() -> Dictionary:
	return {"sick": sick, "next_onset_at": next_onset_at, "rng_state": rng_state}

## Khôi phục từ dữ liệu đã được [method valid] kiểm tra.
func restore(data: Dictionary) -> void:
	sick = data.sick
	next_onset_at = data.next_onset_at
	rng_state = int(data.rng_state)

## Kiểm tra ba trường bắt buộc và miền hợp lệ của trạng thái RNG.
static func valid(data: Variant) -> bool:
	return data is Dictionary and data.size() == 3 and data.get("sick") is bool and SaveSchema.number(data.get("next_onset_at")) and SaveSchema.number(data.get("rng_state"), 1, 2147483646, true)
