extends SceneTree
## Load after autoload initialization, so typed project classes see TimeManager.
func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	root.add_child(load("res://tests/support/offline_load_benchmark_runner.gd").new())
