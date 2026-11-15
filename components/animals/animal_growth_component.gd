class_name AnimalGrowthComponent
extends Node
## Theo dõi tuổi và các mốc trưởng thành, hết tuổi thọ của một con vật.
## Tuổi được cập nhật độc lập với resource loài và trạng thái đói khát.

## Phát khi tuổi vượt mốc trưởng thành.
signal matured
## Phát khi tuổi chạm giới hạn tuổi thọ trong [method advance].
signal lifespan_reached
## Phát sau khi tuổi được tăng, mang tuổi mới tính bằng giây.
signal age_changed(age_seconds: float)
## Cho biết thuốc tăng trưởng con non đã được dùng.
var juvenile_tonic_used: bool = false
## Tuổi hiện tại tính bằng giây.
var age_seconds: float = 0.0
## Tuổi trưởng thành sau khi tính tác dụng thuốc.
var maturity_seconds: float = 86400.0
## Tổng tuổi thọ tính bằng giây.
var lifespan_seconds: float = 1209600.0

## Thiết lập các mốc và tuổi ban đầu, giới hạn tuổi trong khoảng tuổi thọ.
## Nếu thuốc đã dùng, thời gian trưởng thành được giảm một nửa.
func configure(duration: float, initial_age: float = 0.0, lifetime: float = 1209600.0, tonic_used: bool = false) -> void:
	juvenile_tonic_used = tonic_used
	maturity_seconds = maxf(0.0, duration) * (0.5 if tonic_used else 1.0)
	lifespan_seconds = maxf(0.001, lifetime)
	age_seconds = clampf(initial_age, 0.0, lifespan_seconds)

## Trả về true khi tuổi đã đạt mốc trưởng thành.
func is_adult() -> bool:
	return age_seconds >= maturity_seconds

## Số giây còn lại đến trưởng thành, tối thiểu bằng 0.
func seconds_until_adult() -> float:
	return maxf(0.0, maturity_seconds - age_seconds)

## Trả về true khi tuổi đã đạt tuổi thọ.
func is_dead() -> bool:
	return age_seconds >= lifespan_seconds

## Số giây còn lại đến khi hết tuổi thọ, tối thiểu bằng 0.
func seconds_until_death() -> float:
	return maxf(0.0, lifespan_seconds - age_seconds)

## Tỉ lệ tiến tới trưởng thành trong khoảng 0–1.
func progress_ratio() -> float:
	return 1.0 if maturity_seconds <= 0.0 else clampf(age_seconds / maturity_seconds, 0.0, 1.0)

## Tăng tuổi thêm số giây dương và phát các signal khi vượt mốc.
## Nếu đã hết tuổi thọ hoặc thời gian không dương, không cập nhật.
func advance(elapsed: float) -> void:
	if elapsed <= 0.0 or is_dead():
		return
	var was_adult: bool = is_adult()
	age_seconds = minf(age_seconds + elapsed, lifespan_seconds)
	if not was_adult and is_adult():
		matured.emit()
	age_changed.emit(age_seconds)
	if is_dead():
		lifespan_reached.emit()

## Dùng thuốc một lần khi còn non và còn sống, giảm một nửa mốc trưởng thành.
## Phát [signal matured] ngay nếu tuổi hiện tại đã đạt mốc mới. Tuổi và tuổi thọ
## không đổi. Trả về false nếu không thể dùng thuốc.
func apply_juvenile_tonic() -> bool:
	if juvenile_tonic_used or is_adult() or is_dead():
		return false
	juvenile_tonic_used = true
	maturity_seconds *= 0.5
	# Age and lifespan are unchanged, even when this makes the animal adult now.
	if is_adult():
		matured.emit()
	return true
