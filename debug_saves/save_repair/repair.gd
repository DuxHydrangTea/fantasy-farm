extends GutTest

func test_repair() -> void:
	var source: String = "C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/profile_local.json"
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	if String(envelope.payload).sha256_text() != envelope.sha256:
		print("REPAIR_ERROR checksum")
		fail_test("Repair validation failed")
		return
	var data: Dictionary = JSON.parse_string(envelope.payload)
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	await wait_process_frames(2)
	var bridge: WorkerWorldBridge = world.workers.bridge
	var changed: Array = []
	for row: Dictionary in data.workers.rows:
		var pen: AnimalPen = bridge.pen_for(row.zone) if row.role == "ranch" else null
		if row.role == "ranch" and pen == null:
			print("REPAIR_ERROR missing pen ", row.zone)
			fail_test("Repair validation failed")
			return
		var invalid_position: bool = not bridge.zone_contains(row, WorkerRole.point(row.position), int(data.land_columns))
		var invalid_target: bool = not row.task.is_empty() and not bridge.zone_contains(row, WorkerRole.point(row.task.point), int(data.land_columns))
		if invalid_position:
			var destination: Vector2 = bridge.home(row.role, row.zone)
			if row.role == "crop":
				var cell: Vector2i = Vector2i(LandExpansionState.REGION.end.x - int(data.land_columns) + 1, LandExpansionState.REGION.position.y + 1)
				destination = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))
			row.position = WorkerRole.pair(destination)
		if invalid_position or invalid_target:
			row.task = {}
			row.wake_at = data.workers.simulated_at
			changed.append({"id": row.id, "role": row.role, "position": row.position, "reset_task": true})
	var checked: Dictionary = SaveSchema.validate(data, SaveCatalog.new())
	print("VALIDATION ", JSON.stringify(checked if not checked.ok else {"ok": true}))
	if not checked.ok:
		fail_test("Repair validation failed")
		return
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var preflight: Dictionary = adapter.preflight(checked.snapshot)
	print("PREFLIGHT ", JSON.stringify(preflight))
	if not preflight.ok:
		fail_test("Repair validation failed")
		return
	var payload: String = JSON.stringify(data)
	var output: FileAccess = FileAccess.open("res://debug_saves/save_repair/repaired.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"format": "fantasy_farm_save", "payload": payload, "sha256": payload.sha256_text()}, "\t"))
	output.close()
	print("CHANGES ", JSON.stringify(changed))
	assert_true(preflight.ok)
