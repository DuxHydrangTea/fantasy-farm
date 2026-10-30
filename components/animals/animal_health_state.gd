extends RefCounted
const RULES: Resource = preload("res://resources/farm_health_rules.tres")
var sick: bool = false
var next_onset_at: float = 0.0
var rng_state: int = 1

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

func cure(timestamp: float) -> bool:
	if not sick:
		return false
	sick = false
	_schedule(timestamp + float(RULES.protection_seconds))
	return true

func capture() -> Dictionary:
	return {"sick": sick, "next_onset_at": next_onset_at, "rng_state": rng_state}

func restore(data: Dictionary) -> void:
	sick = data.sick
	next_onset_at = data.next_onset_at
	rng_state = int(data.rng_state)

static func valid(data: Variant) -> bool:
	return data is Dictionary and data.size() == 3 and data.get("sick") is bool and SaveSchema.number(data.get("next_onset_at")) and SaveSchema.number(data.get("rng_state"), 1, 2147483646, true)
