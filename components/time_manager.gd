class_name FarmClock
extends Node

## Shared farm timeline. Session mode freezes time while the game is closed;
## wall-clock mode remains available for offline simulation and test clocks.
signal tick(timestamp: float)
signal before_tick(timestamp: float)
@export_range(0.05, 1.0) var refresh_interval: float = 0.1
var clock_source: Callable = Time.get_unix_time_from_system:
	set(value):
		clock_source = value
		_session_mode = false
## Synchronous world catch-up scope; never advances the wall-clock floor backwards.
var simulation_timestamp: float = -1.0
var _last_timestamp: float = 0.0
var _poll_elapsed: float = 0.0
var _session_mode: bool = false
var _session_timestamp: float = 0.0
var _freeze_gaps: bool = true

func begin_session(timestamp: float, freeze_gaps: bool = true) -> void:
	# Each farm owns its timeline. A different profile may have an earlier date.
	_session_mode = true
	_freeze_gaps = freeze_gaps
	_session_timestamp = timestamp
	_last_timestamp = timestamp
	simulation_timestamp = -1.0
	_poll_elapsed = 0.0

func use_wall_clock(timestamp: float) -> void:
	_session_mode = false
	_last_timestamp = timestamp
	simulation_timestamp = -1.0

# MỐC THỜI GIAN CHUNG — cần cho tiến trình lưu/tải và lớn khi offline.
# Lấy max(mốc đã thấy, giờ hệ thống) để thời gian của game không lùi trong phiên này.
# Ví dụ đã tính cây đến giây 1000 nhưng máy bị chỉnh về 900: trả 1000, không làm cây non lại.
# Nếu chỉ trả giờ hệ thống, tiến độ/no/nước có thể bị tính lùi hoặc cùng một khoảng bị tính lại.
# Đây không phải chống gian lận: chỉnh đồng hồ tiến vẫn có thể đẩy thời gian offline đi nhanh.
# Sau này online cần giờ đáng tin cậy từ server, không dựa vào đồng hồ client để trao thưởng.
func now() -> float:
	if simulation_timestamp >= 0.0:
		return simulation_timestamp
	if _session_mode:
		return _session_timestamp
	# Moving the system clock backwards must not undo already earned growth.
	_last_timestamp = maxf(_last_timestamp, float(clock_source.call()))
	return _last_timestamp

func _process(delta: float) -> void:
	if _session_mode:
		_session_timestamp += minf(delta, 0.25) if _freeze_gaps else delta
	_poll_elapsed += delta
	if _poll_elapsed >= refresh_interval:
		_poll_elapsed = 0.0
		refresh()

func refresh() -> void:
	var timestamp: float = now()
	before_tick.emit(timestamp)
	tick.emit(timestamp)

# Khi tải save, đặt sàn thời gian ít nhất bằng saved_at để đồng hồ hiện tại thấp hơn save
# không đảo ngược tiến trình. Không cộng thêm một lần tăng trưởng ở đây: từng hệ thống
# sẽ tính chênh lệch từ timestamp đã lưu của chính nó; cộng tại cả hai nơi sẽ bị nhân đôi.
func advance_floor(timestamp: float) -> void:
	if is_finite(timestamp) and timestamp >= 0.0:
		_last_timestamp = maxf(_last_timestamp, timestamp)
