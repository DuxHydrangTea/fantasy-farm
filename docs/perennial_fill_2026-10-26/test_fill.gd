extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const OUTPUT: String = "res://docs/perennial_fill_2026-10-26"

func test_build_balanced_mature_plantation_and_restore_world() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT + "/profile_before.json")) as Dictionary
	assert_eq(str(envelope.payload).sha256_text(), envelope.sha256)
	var checked: Dictionary = SaveSchema.validate(JSON.parse_string(envelope.payload), catalog)
	assert_true(checked.ok, str(checked))
	if not checked.ok:
		return
	var snapshot: Dictionary = checked.snapshot
	var before: Dictionary = snapshot.duplicate(true)
	var now: float = float(snapshot.saved_at)
	var fruit: Array[String] = []
	var timber: Array[String] = []
	for id: String in catalog.trees:
		var definition: TreeDefinition = catalog.trees[id] as TreeDefinition
		if definition.kind == TreeDefinition.Kind.FRUIT:
			fruit.append(id)
		else:
			timber.append(id)
	fruit.sort()
	timber.sort()
	assert_eq(fruit.size(), 4)
	assert_eq(timber.size(), 17)
	var rows: Array = []
	var counts: Dictionary = {}
	for kind: TreeDefinition.Kind in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var region: Rect2i = TreePlantation.region_for(kind)
		var ids: Array[String] = fruit if kind == TreeDefinition.Kind.FRUIT else timber
		var index: int = 0
		for y: int in range(region.position.y + 3, region.end.y - 1, 3):
			var row_index: int = floori(float(y - region.position.y - 3) / 3.0)
			var column: int = 0
			for x: int in range(region.position.x + 2, region.end.x - 1, 3):
				var cell: Vector2i = Vector2i(x, y)
				assert_true(TreePlantation.valid_cell(cell, kind))
				var id: String = ids[index % ids.size()] if kind == TreeDefinition.Kind.FRUIT else ids[(column + row_index * 3) % ids.size()]
				var definition: TreeDefinition = catalog.trees[id] as TreeDefinition
				var tree: PerennialTree = FruitTree.new() if kind == TreeDefinition.Kind.FRUIT else TimberTree.new()
				tree.definition = definition
				tree.cell = cell
				var planted: float = now - definition.growth_seconds - definition.fruit_cycle_seconds - 1.0
				tree.initialize(planted)
				if tree is FruitTree:
					(tree as FruitTree).water(planted)
				tree.refresh(now)
				assert_true(tree.is_mature())
				rows.append(tree.capture())
				counts[id] = int(counts.get(id, 0)) + 1
				tree.free()
				index += 1
				column += 1
	snapshot.trees = rows
	snapshot.revision = int(snapshot.revision) + 1
	assert_eq(rows.size(), 306)
	for id: String in timber:
		assert_eq(int(counts[id]), 9, id)
	for id: String in fruit:
		assert_between(int(counts[id]), 38, 39, id)
	for key: String in before:
		if key not in ["trees", "revision"]:
			assert_eq(snapshot[key], before[key], "Preserve " + key)
	checked = SaveSchema.validate(snapshot, catalog)
	assert_true(checked.ok, str(checked))
	if not checked.ok:
		return
	var payload: String = JSON.stringify(checked.snapshot)
	var file: FileAccess = FileAccess.open(OUTPUT + "/profile_local.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":"fantasy_farm_save", "payload":payload, "sha256":payload.sha256_text()}, "\t"))
	file.close()
	var repository: LocalSaveRepository = LocalSaveRepository.new(OUTPUT, catalog)
	var reread: Dictionary = repository.read_profile("local")
	assert_true(reread.ok, str(reread))
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var preflight: Dictionary = adapter.preflight(snapshot)
	assert_true(preflight.ok, str(preflight))
	if preflight.ok:
		var restored: Dictionary = adapter.restore(snapshot, now)
		assert_true(restored.ok, str(restored))
		assert_eq(world.trees.trees.size(), 306)
		var positions: Dictionary = {}
		for tree: PerennialTree in world.trees.trees.values():
			assert_true(tree.is_mature())
			assert_false(positions.has(tree.position))
			positions[tree.position] = true
			assert_eq(tree.sprite.texture, tree.definition.ready_texture)
			if tree is TimberTree:
				assert_false((tree as TimberTree).stump)
			else:
				assert_true((tree as FruitTree).has_fruit())
	world.free()
	file = FileAccess.open(OUTPUT + "/summary.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"tree_count":rows.size(), "counts":counts, "revision":snapshot.revision, "saved_at":now}, "\t"))
	file.close()
