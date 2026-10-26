extends Node

const FOLDER: String = "res://debug_saves/full_flowers_2026-10-26"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var repository: LocalSaveRepository = LocalSaveRepository.new(FOLDER)
	var checked: Dictionary = repository.read_profile("local")
	if not checked.get("ok",false):
		printerr(JSON.stringify(checked))
		get_tree().quit(1)
		return
	var world: FarmWorld = (load("res://world/main_world.tscn") as PackedScene).instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	var manager: GameSaveManager = get_node("/root/SaveManager") as GameSaveManager
	var restored: Dictionary = await manager.bind_world(world,repository)
	manager.writes_enabled = false
	if not restored.ok:
		printerr(JSON.stringify(restored))
		get_tree().quit(1)
		return
	var entities: Dictionary = manager.adapter._collect_world_entities()
	var counts: Dictionary = {}
	var total: int = 0
	for garden: FlowerGarden in entities.gardens:
		for pot: FlowerPot in garden.pots.values():
			if pot.reserved:
				assert(pot.definition == null)
				continue
			assert(pot.definition != null and pot.is_mature())
			var id: String = String(pot.definition.flower_id)
			counts[id] = int(counts.get(id,0))+1
			total += 1
	assert(total == 177 and counts.size() == 10)
	var report: Dictionary = {"ok":true,"flowers":total,"types":counts,"world_restore_verified":true,"revision":checked.revision}
	var file: FileAccess = FileAccess.open(FOLDER+"/verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("FULL_FLOWERS_VALIDATED " + JSON.stringify(report))
	get_tree().quit(0)
