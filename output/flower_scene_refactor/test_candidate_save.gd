extends GutTest

func test_candidate_loads_into_world() -> void:
	var repository: LocalSaveRepository = LocalSaveRepository.new("res://output/flower_scene_refactor")
	var result: Dictionary = repository._read("res://output/flower_scene_refactor/flower-save-candidate.json", "local")
	assert_true(result.ok, str(result))
	if not result.ok:
		return
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate()
	assert_engine_error("invalid UID: uid://1447j7kch4l0")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checked: Dictionary = adapter.preflight(result.snapshot)
	assert_true(checked.ok, str(checked))
	if checked.ok:
		var restored: Dictionary = adapter.restore(result.snapshot, float(result.snapshot.saved_at))
		assert_true(restored.ok, str(restored))
		var garden: FlowerGarden = world.get_node("FlowerGarden")
		var species: Dictionary = {}
		var planted: int = 0
		for pot: FlowerPot in garden.pots.values():
			if pot.definition != null:
				planted += 1
				species[pot.definition.flower_id] = true
		assert_eq(planted, 77)
		assert_eq(species.size(), 30)
