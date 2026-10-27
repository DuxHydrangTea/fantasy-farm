extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var repo: LocalSaveRepository = LocalSaveRepository.new("res://output/flower_scene_refactor")
	var result: Dictionary = repo._read("res://output/flower_scene_refactor/flower-save-candidate.json", "local")
	if not result.ok:
		printerr("SAVE_VALIDATION_FAILED: ", result)
		quit(1)
		return
	var snapshot: Dictionary = result.snapshot
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checked: Dictionary = adapter.preflight(snapshot)
	if not checked.ok:
		printerr("PREFLIGHT_FAILED: ", checked)
		quit(2)
		return
	print("SAVE_SCHEMA_AND_PREFLIGHT_OK: revision=", snapshot.revision)
	world.free()
	quit()
