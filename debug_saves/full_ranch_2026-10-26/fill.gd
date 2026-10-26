extends Node

const FOLDER: String = "res://debug_saves/full_ranch_2026-10-26"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var repository: LocalSaveRepository = LocalSaveRepository.new(FOLDER, catalog)
	var loaded: Dictionary = repository.read_profile("local")
	if not loaded.get("ok", false) or not loaded.get("found", false):
		_fail(loaded)
		return
	var original: Dictionary = loaded.snapshot
	var data: Dictionary = original.duplicate(true)
	var world: FarmWorld = (load("res://world/main_world.tscn") as PackedScene).instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var entities: Dictionary = adapter._collect_world_entities()
	var animals: Array = []
	var pen_counts: Dictionary = {}
	var species_counts: Dictionary = {}
	var skin_counts: Dictionary = {}
	var use_counts: Dictionary = {}
	for pen: AnimalPen in entities.pens:
		var pen_id: String = String(pen.persistent_id)
		if not PenUpgradeState.CATALOG.pen_kinds.has(pen_id):
			continue
		data.pen_upgrades[pen_id] = PenUpgradeState.MAX_LEVEL
		var kind: String = String(PenUpgradeState.CATALOG.pen_kinds[pen_id])
		var species: Array = ["chicken"] if kind == "coop" else ["cow", "sheep", "pig", "horse"] if kind == "barn" else ["duck", "goose"]
		var bounds: Rect2 = pen.allowed_bounds(28.0)
		for index: int in range(30):
			var animal_id: String = species[index % species.size()]
			var definition: AnimalDefinition = catalog.animals[animal_id] as AnimalDefinition
			var skins: Array[String] = []
			for skin: String in catalog.skins:
				if catalog.valid_skin(animal_id, skin):
					skins.append(skin)
			skins.sort()
			var used: int = int(use_counts.get(animal_id, 0))
			var skin: String = skins[used % skins.size()]
			use_counts[animal_id] = used + 1
			var point: Vector2 = bounds.position + Vector2((index % 6 + 0.5) * bounds.size.x / 6.0, (int(index / 6.0) + 0.5) * bounds.size.y / 5.0)
			animals.append({"id":"full_ranch_%s_%02d" % [animal_id,index],"animal":animal_id,"skin":skin,"pen":pen_id,"position":[point.x,point.y],"facing":"down","age":definition.maturity_seconds+3600.0,"satiety":100.0,"hydration":100.0,"production_progress":0.0,"production_stock":0,"pickup":"","juvenile_tonic_used":false,"tonic_pending":false})
			pen_counts[pen_id] = int(pen_counts.get(pen_id,0))+1
			species_counts[animal_id] = int(species_counts.get(animal_id,0))+1
			skin_counts[skin] = int(skin_counts.get(skin,0))+1
	assert(animals.size() == 90 and pen_counts.size() == 3)
	data.animals = animals
	var troughs: Array = []
	for trough: AnimalTrough in entities.troughs:
		var point: Vector2 = trough.position
		troughs.append({"id":String(trough.persistent_id),"pen":String(trough.pen.persistent_id),"position":[point.x,point.y],"stock":trough.capacity,"feed_reserve":0,"consumed_fraction":0.0})
	data.troughs = troughs
	var trees: Array = []
	for row: Dictionary in data.trees:
		if (catalog.trees[row.tree] as TreeDefinition).kind == TreeDefinition.Kind.TIMBER:
			trees.append(row)
	var fruit_ids: Array[String] = []
	for id: String in catalog.trees:
		if (catalog.trees[id] as TreeDefinition).kind == TreeDefinition.Kind.FRUIT:
			fruit_ids.append(id)
	fruit_ids.sort()
	var fruit_counts: Dictionary = {}
	for row: int in range(9):
		for column: int in range(17):
			var id: String = fruit_ids[(column + row * 5) % fruit_ids.size()]
			var definition: TreeDefinition = catalog.trees[id] as TreeDefinition
			var mature: float = float(data.saved_at) - definition.fruit_cycle_seconds
			var planted: float = mature - definition.growth_seconds
			trees.append({"tree":id,"cell":[12+column*3,61+row*3],"planted_at":planted,"growth_started_at":planted,"matures_at":mature,"last_at":data.saved_at,"fruit_work":definition.fruit_cycle_seconds,"active_graft":0,"pending_graft":0,"graft_revision":0})
			fruit_counts[id] = int(fruit_counts.get(id,0))+1
	data.trees = trees
	data.tree_plot_upgrades.fruit = TreePlotUpgradeState.MAX_LEVEL
	data.revision = int(original.revision)+1
	var changed: Array[String] = []
	for key: String in original:
		if data[key] != original[key]:
			changed.append(key)
		if not key in ["animals","pen_upgrades","troughs","trees","tree_plot_upgrades","revision"]:
			assert(data[key] == original[key], key)
	assert(data.soil == original.soil and data.crops == original.crops and data.land_columns == original.land_columns)
	var checked: Dictionary = SaveSchema.validate(data, catalog)
	if not checked.ok:
		_fail(checked)
		return
	var preflight: Dictionary = adapter.preflight(data)
	if not preflight.ok:
		_fail(preflight)
		return
	var result: Dictionary = repository.write_profile("local", data, int(original.revision))
	if not result.ok:
		_fail(result)
		return
	var manager: GameSaveManager = get_node("/root/SaveManager") as GameSaveManager
	var restored: Dictionary = await manager.bind_world(world, repository)
	manager.writes_enabled = false
	if not restored.ok:
		_fail(restored)
		return
	var live: Dictionary = adapter._collect_world_entities()
	assert(live.animals.size() == 90)
	for pen: AnimalPen in live.pens:
		assert(pen.capacity == 30)
	for animal: AnimalActor in live.animals:
		assert(animal.growth.is_adult())
	var report: Dictionary = {"ok":true,"revision":data.revision,"animal_count":90,"pens":pen_counts,"species":species_counts,"skin_variants":skin_counts.size(),"fruit_count":153,"fruit_species":fruit_counts,"troughs_filled":troughs.size(),"soil_preserved":true,"crops_preserved":true,"land_expansion_preserved":true,"changed_fields":changed,"world_restore_verified":true}
	var file: FileAccess = FileAccess.open(FOLDER + "/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("FULL_RANCH_VALIDATED " + JSON.stringify(report))
	get_tree().quit(0)

func _fail(result: Dictionary) -> void:
	printerr(JSON.stringify(result))
	get_tree().quit(1)
