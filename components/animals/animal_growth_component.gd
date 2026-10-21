class_name AnimalGrowthComponent
extends Node
## Per-animal age, independent of the species Resource and of hunger.
signal matured
signal lifespan_reached
signal age_changed(age_seconds: float)
var juvenile_tonic_used: bool = false
var age_seconds: float = 0.0
var maturity_seconds: float = 86400.0
var lifespan_seconds: float = 1209600.0

func configure(duration: float, initial_age: float = 0.0, lifetime: float = 1209600.0, tonic_used: bool = false) -> void:
	juvenile_tonic_used = tonic_used
	maturity_seconds = maxf(0.0, duration) * (0.5 if tonic_used else 1.0)
	lifespan_seconds = maxf(0.001, lifetime)
	age_seconds = clampf(initial_age, 0.0, lifespan_seconds)

func is_adult() -> bool:
	return age_seconds >= maturity_seconds

func seconds_until_adult() -> float:
	return maxf(0.0, maturity_seconds - age_seconds)

func is_dead() -> bool:
	return age_seconds >= lifespan_seconds

func seconds_until_death() -> float:
	return maxf(0.0, lifespan_seconds - age_seconds)

func progress_ratio() -> float:
	return 1.0 if maturity_seconds <= 0.0 else clampf(age_seconds / maturity_seconds, 0.0, 1.0)

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

func apply_juvenile_tonic() -> bool:
	if juvenile_tonic_used or is_adult() or is_dead():
		return false
	juvenile_tonic_used = true
	maturity_seconds *= 0.5
	# Age and lifespan are unchanged, even when this makes the animal adult now.
	if is_adult():
		matured.emit()
	return true
