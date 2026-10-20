class_name AnimalGrowthComponent
extends Node
## Per-animal age, independent of the species Resource and of hunger.
signal matured
signal age_changed(age_seconds: float)
var age_seconds: float = 0.0
var maturity_seconds: float = 120.0

func configure(duration: float, initial_age: float = 0.0) -> void:
	maturity_seconds = maxf(0.0, duration)
	age_seconds = maxf(0.0, initial_age)

func is_adult() -> bool:
	return age_seconds >= maturity_seconds

func seconds_until_adult() -> float:
	return maxf(0.0, maturity_seconds - age_seconds)

func progress_ratio() -> float:
	return 1.0 if maturity_seconds <= 0.0 else clampf(age_seconds / maturity_seconds, 0.0, 1.0)

func advance(elapsed: float) -> void:
	if elapsed <= 0.0:
		return
	var was_adult: bool = is_adult()
	age_seconds += elapsed
	if not was_adult and is_adult():
		matured.emit()
	age_changed.emit(age_seconds)
