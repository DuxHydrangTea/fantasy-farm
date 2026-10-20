class_name FarmClock
extends Node

## Shared Unix clock. Growth uses timestamps; delta only limits UI refresh rate.
signal tick(timestamp: float)
@export_range(0.05, 1.0) var refresh_interval: float = 0.1
var clock_source: Callable = Time.get_unix_time_from_system
var _last_timestamp: float = 0.0
var _poll_elapsed: float = 0.0

func now() -> float:
	# Moving the system clock backwards must not undo already earned growth.
	_last_timestamp = maxf(_last_timestamp, float(clock_source.call()))
	return _last_timestamp

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed >= refresh_interval:
		_poll_elapsed = 0.0
		refresh()

func refresh() -> void:
	tick.emit(now())

func advance_floor(timestamp: float) -> void:
	if is_finite(timestamp) and timestamp >= 0.0:
		_last_timestamp = maxf(_last_timestamp, timestamp)
