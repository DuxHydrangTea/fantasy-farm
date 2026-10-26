extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var root: Window = get_tree().root
	var folder: String = "res://debug_saves/perennial_fill_2026-10-26"
	var repository: LocalSaveRepository = LocalSaveRepository.new(folder)
	var checked: Dictionary = repository.read_profile("local")
	if not checked.get("ok", false) or not checked.get("found", false):
		printerr(JSON.stringify(checked))
		get_tree().quit(1)
		return
	assert(checked.snapshot.trees.size() == 306)
	var manager: GameSaveManager = root.get_node("SaveManager") as GameSaveManager
	manager.local_directory = folder
	var world: Node = (load("res://world/main_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var restored: Dictionary = await manager.bind_world(world)
	if not restored.get("ok", false):
		printerr(JSON.stringify(restored))
		get_tree().quit(1)
		return
	manager.writes_enabled = false
	assert(manager.adapter != null and not manager.busy)
	assert(manager.revision == int(checked.revision))
	var plantation: TreePlantation = world.get("trees") as TreePlantation
	assert(plantation.trees.size() == 306)
	var counts: Dictionary = {}
	for tree: PerennialTree in plantation.trees.values():
		assert(tree.is_mature())
		var id: String = String(tree.definition.tree_id)
		counts[id] = int(counts.get(id,0)) + 1
	assert(counts.size() == 21)
	print("PERENNIAL_FILL_VALIDATED " + JSON.stringify({"trees":306,"species":counts,"revision":manager.revision,"schema":true,"world_restore":true,"all_mature":true}))
	get_tree().quit(0)
