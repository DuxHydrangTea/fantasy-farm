extends Node
## Optional native runner; regular GUT discovery also picks up the same tests.
const GUT: GDScript = preload("res://addons/gut/gut.gd")
var runner: Node
var results: Dictionary = {}
@export var regressions: bool = false

func _ready() -> void:
	if regressions:
		results = {"ready": true}
		run_regressions()
		return
	runner = GUT.new()
	add_child(runner)
	runner.end_run.connect(_finished)
	runner.add_script("res://tests/unit/test_farm_health.gd")
	runner.add_script("res://tests/unit/test_status_bubbles.gd")
	runner.add_script("res://tests/integration/test_farm_health_world.gd")
	runner.add_script("res://tests/unit/test_crop_growth.gd")
	runner.add_script("res://tests/unit/test_animal_production.gd")
	runner.test_scripts.call_deferred()

func _finished() -> void:
	results = {"tests": runner.get_test_count(), "assertions": runner.get_assert_count(), "failures": runner.get_fail_count()}
	print("FARM_HEALTH_TESTS ", JSON.stringify(results))

func run_regressions() -> void:
	if results.is_empty():
		return
	if is_instance_valid(runner):
		runner.queue_free()
	runner = GUT.new()
	add_child(runner)
	results = {}
	runner.end_run.connect(_finished)
	for path: String in ["res://tests/unit/test_boosters.gd", "res://tests/unit/test_pen_offline.gd", "res://tests/unit/test_worker_roles.gd", "res://tests/integration/test_farm_storage_world.gd", "res://tests/integration/test_offline_policy.gd", "res://tests/integration/test_crop_quality.gd"]:
		runner.add_script(path)
	runner.test_scripts.call_deferred()
