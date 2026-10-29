extends GutTest
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")

func test_priority_distance_and_stable_ties() -> void:
	var tasks: Array[Dictionary] = [{"id": "b", "priority": 1, "point": [0, 0]}, {"id": "z", "priority": 0, "point": [10, 0]}, {"id": "a", "priority": 0, "point": [-10, 0]}]
	assert_eq(WorkerRole.choose(tasks, Vector2.ZERO).id, "a")
	assert_eq(WorkerRole.choose(tasks, Vector2(10, 0)).id, "z")
	assert_true(WorkerRole.choose([], Vector2.ZERO).is_empty())

func test_worker_stack_cap_is_runtime_and_player_inventory_is_unchanged() -> void:
	var worker: InventoryComponent = InventoryComponent.new()
	worker.starting_tools = false
	worker.slot_count = 16
	worker.stack_cap = 100
	add_child_autofree(worker)
	assert_eq(worker.capacity_for(APPLE), 1600)
	assert_eq(worker.add(APPLE, 300), 300)
	for index: int in range(3):
		assert_eq(worker.get_slot_count(index), 100)
	assert_eq(worker.add(APPLE, 2000), 1300)
	assert_eq(worker.capacity_for(APPLE), 0)
	var player: InventoryComponent = InventoryComponent.new()
	player.starting_tools = false
	add_child_autofree(player)
	assert_eq(player.add(APPLE, 300), 300)
	assert_eq(player.get_slot_count(0), 300)

func test_fresh_schema_and_invalid_fields() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	assert_true(WorkerSaveSchema.valid(WorkerSaveSchema.fresh(), catalog, 1000.0))
	var data: Dictionary = WorkerSaveSchema.fresh()
	data.simulated_at = NAN
	assert_false(WorkerSaveSchema.valid(data, catalog, 1000.0))
	data = WorkerSaveSchema.fresh()
	data.trial_used = ["orchard", "orchard"]
	assert_false(WorkerSaveSchema.valid(data, catalog, 1000.0))

func test_task_selection_is_stable_under_input_permutations_and_returns_an_owned_copy() -> void:
	var tasks: Array[Dictionary] = [
		{"id": "b", "priority": 0, "point": [10.0, 0.0], "cell": [2, 3]},
		{"id": "a", "priority": 0, "point": [-10.0, 0.0], "cell": [4, 5]},
		{"id": "near", "priority": 1, "point": [0.0, 0.0], "cell": [6, 7]}]
	var original: Array[Dictionary] = tasks.duplicate(true)
	for permutation: Array in [[0, 1, 2], [2, 1, 0], [1, 0, 2], [1, 2, 0], [0, 2, 1], [2, 0, 1]]:
		var ordered: Array[Dictionary] = []
		for index: int in permutation:
			ordered.append(tasks[index])
		var selected: Dictionary = WorkerRole.choose(ordered, Vector2.ZERO)
		assert_eq(selected.id, "a", "Batching must preserve priority/distance/ID tie-breaking")
		selected.point[0] = 999.0
		selected.cell[0] = 999
	assert_eq(tasks, original, "Committing a selected task must not mutate the candidate index")

func test_worker_checkpoint_rejects_future_time_and_nonfinite_time() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	for timestamp: float in [1000.0001, INF, -INF, NAN, -1.0]:
		var data: Dictionary = WorkerSaveSchema.fresh()
		data.simulated_at = timestamp
		assert_false(WorkerSaveSchema.valid(data, catalog, 1000.0), "A catch-up cursor must not escape the checkpoint time")
