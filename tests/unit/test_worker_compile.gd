extends GutTest
## Minimal compile test to verify worker_world_bridge changes don't break syntax.

const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_worker_world_bridge_compiles_and_instantiates() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	
	assert_not_null(world.workers, "WorkerService should exist")
	assert_not_null(world.workers.bridge, "WorkerWorldBridge should exist")
	assert_not_null(world.workers.crop_policy, "CropWorkerPolicy should exist")
	
	# Verify new cache variables exist
	assert_true(world.workers.bridge.has_meta("_trough_point_cache") or "_trough_point_cache" in world.workers.bridge, "Should have trough cache")

func test_candidates_method_signature() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(1000000)
	
	var error: String = world.workers.hire("crop")
	assert_eq(error, "", "Should hire worker successfully")
	
	var row: Dictionary = world.workers.record("crop")
	var feed_inv: InventoryComponent = world.workers.feed_inventory("crop")
	
	# This call verifies the signature matches
	var tasks: Array[Dictionary] = world.workers.bridge.candidates(row, feed_inv)
	assert_true(tasks is Array, "candidates() should return Array[Dictionary]")

func test_crop_policy_accessible_from_bridge() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	
	# Verify the path that was causing compile error
	assert_not_null(world.workers.crop_policy, "crop_policy should be accessible")
	assert_true(world.workers.crop_policy is CropWorkerPolicy, "Should be CropWorkerPolicy type")
