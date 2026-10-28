extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var repository: LocalSaveRepository = LocalSaveRepository.new("user://saves", catalog)
	var result: Dictionary = repository.read_profile("local")
	if not result.ok or not result.get("found", false):
		_fail(result)
		return
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var original: Dictionary = result.snapshot
	var checked: Dictionary = adapter.preflight(original)
	if not checked.ok:
		world.free()
		_fail(checked)
		return
	var updated: Dictionary = checked.snapshot
	for index: int in range(original.beehives.size()):
		var before: Dictionary = original.beehives[index].duplicate(true)
		var after: Dictionary = updated.beehives[index].duplicate(true)
		before.erase("position")
		after.erase("position")
		assert(before == after, "Hive production state changed")
	var before_other: Dictionary = original.duplicate(true)
	var after_other: Dictionary = updated.duplicate(true)
	before_other.erase("beehives")
	after_other.erase("beehives")
	assert(before_other == after_other, "Unrelated progress changed")
	var restored: Dictionary = adapter.restore(updated, float(updated.saved_at))
	if not restored.ok:
		world.free()
		_fail(restored)
		return
	for hive: Beehive in world.apiary.hives:
		assert(hive.global_position == world.honey_garden.center_point(hive.garden_slot))
		assert(world.honey_garden.inside(hive))
	var payload: String = JSON.stringify(updated)
	var envelope: Dictionary = {"format":"fantasy_farm_save", "payload":payload, "sha256":payload.sha256_text()}
	var file: FileAccess = FileAccess.open("res://debug_saves/hive_relocation/profile_local.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	var report: Dictionary = {"ok":true, "revision":updated.revision, "hives":updated.beehives.size(), "positions":[], "production_preserved":true, "other_progress_preserved":true}
	for row: Dictionary in updated.beehives:
		report.positions.append(row.position)
	file = FileAccess.open("res://debug_saves/hive_relocation/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	world.free()
	get_tree().quit(0)

func _fail(result: Dictionary) -> void:
	push_error(JSON.stringify(result))
	get_tree().quit(1)
