extends Node
## Explicit opt-in preparation tool. Never runs from the game or on a new profile.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var catalog: SaveCatalog

func _ready() -> void:
	_run.call_deferred()

func _finish(report: Dictionary, path: String) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print(JSON.stringify(report))
	if is_instance_valid(world):
		world.free()
	get_tree().quit(0 if report.get("ok",false) else 1)

func _bag(rows: Array, cap: int = 0) -> InventoryComponent:
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.starting_tools = false
	inventory.slot_count = rows.size()
	inventory.stack_cap = cap
	get_tree().root.add_child(inventory)
	var stacks: Array[Dictionary] = []
	for row: Dictionary in rows:
		stacks.append({"item":catalog.items.get(row.item),"count":int(row.count),"tiers":row.tiers.duplicate()})
	if not inventory.replace_slots(stacks,false):
		inventory.free()
		return null
	return inventory

func _rows(inventory: InventoryComponent) -> Array:
	var result: Array = []
	for i: int in range(inventory.slot_count):
		var row: Dictionary = inventory.slot(i)
		result.append({"item":String(row.item.item_id) if row.item != null else "","count":int(row.count),"tiers":row.tiers.duplicate()})
	return result

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		get_tree().quit(1)
		return
	catalog = SaveCatalog.new()
	var repo: LocalSaveRepository = LocalSaveRepository.new(args[0],catalog)
	var loaded: Dictionary = repo.read_profile("local")
	if not loaded.ok or not loaded.get("found",false):
		_finish({"ok":false,"error":"Existing profile could not be read."},args[1])
		return
	var source_hash: String = FileAccess.get_file_as_string(repo.path("local")).sha256_text()
	var apply: bool = args.size() >= 4 and args[2] == "--apply"
	if apply and args[3] != source_hash:
		_finish({"ok":false,"error":"The source profile changed after preview."},args[1])
		return
	var data: Dictionary = loaded.snapshot.duplicate(true)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,catalog)
	var original: Dictionary = adapter.preflight(data)
	if not original.ok:
		_finish(original,args[1])
		return
	var bag: InventoryComponent = _bag(data.inventory)
	var requirements: Dictionary = {}
	for row: Dictionary in data.orders.slots:
		if row.is_empty():
			continue
		var entry: OrderDefinition = OrderService.DEFAULT_CATALOG.find(StringName(row.template))
		for i: int in range(entry.items.size()):
			var id: String = String(entry.items[i].item_id)
			requirements[id] = int(requirements.get(id,0))+entry.amounts[i]
	var grants: Array[Dictionary] = []
	for id: String in requirements:
		var item: ItemDefinition = catalog.items[id]
		var targets: Array[int] = [int(requirements[id]),int(requirements[id])/2,int(requirements[id])-int(requirements[id])/2]
		for tier: int in range(3):
			var amount: int = maxi(0,targets[tier]-bag.count_item(item.item_id,tier))
			if amount > 0:
				if bag.add(item,amount,tier,false) != amount:
					_finish({"ok":false,"error":"Not enough bag space. No profile changes written."},args[1])
					return
				grants.append({"item":id,"tier":tier,"amount":amount})
	data.inventory = _rows(bag)
	bag.free()
	var stock: Dictionary = data.storages.farm_supply_storage
	var supplies: InventoryComponent = _bag(stock.slots,int(stock.stack_cap))
	var seed: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
	var seed_grant: int = maxi(0,24-supplies.count_item(seed.item_id))
	if supplies.add(seed,seed_grant,0,false) != seed_grant:
		_finish({"ok":false,"error":"Not enough supply storage space."},args[1])
		return
	data.storages.farm_supply_storage.slots = _rows(supplies)
	supplies.free()
	data.storage_seed = String(seed.item_id)
	var blocked: Dictionary = {}
	for row: Dictionary in data.crops + data.trees:
		blocked[Vector2i(int(row.cell[0]),int(row.cell[1]))] = true
	for row: Dictionary in data.beehives:
		blocked[world.farming.world_to_cell(world.to_global(Vector2(row.position[0],row.position[1])))] = true
	var plots: Array[Dictionary] = []
	for fertile: bool in [false,true]:
		var count: int = 0
		for y: int in range(19,53):
			for x: int in range(56,maxi(8,57-int(data.land_columns))-1,-1):
				var cell: Vector2i = Vector2i(x,y)
				if count >= 2 or blocked.has(cell) or world.farming.cell_is_occupied(cell) or world.farming.fertility.is_fertile(cell) != fertile:
					continue
				var tier: int = 1+count
				data.crops.append({"cell":[x,y],"crop":"carrot","planted_at":float(data.saved_at)-120,"matures_at":float(data.saved_at)-1,"progress":1.0,"watered":true,"root_boost":tier==2,"fertilized":false,"pollination_reduction":0.0})
				var soil: Dictionary = {"cell":[x,y],"state":2,"moisture":FarmingController.SOIL_MOISTURE_SECONDS}
				var soil_found: bool = false
				for old: Dictionary in data.soil:
					if int(old.cell[0]) == x and int(old.cell[1]) == y:
						old.state = 2
						old.moisture = soil.moisture
						soil_found = true
				if not soil_found:
					data.soil.append(soil)
				blocked[cell] = true
				plots.append({"cell":[x,y],"fertile":fertile,"tier":tier,"yield":world.farming.fertility.amount(cell,(seed.crop as CropDefinition).harvest_amount)})
				count += 1
	var worker_paused: bool = false
	for row: Dictionary in data.workers.rows:
		if row.role == "crop":
			data.workers.crop_automation.paused = true
			data.workers.crop_automation.revision = int(data.workers.crop_automation.revision)+1
			if float(row.paused_at) == 0.0:
				row.paused_at = float(data.saved_at)
			worker_paused = true
	data.revision = int(loaded.revision)+1
	var check: Dictionary = adapter.preflight(data)
	if not check.ok:
		_finish(check,args[1])
		return
	var report: Dictionary = {"ok":true,"applied":false,"source_sha256":source_hash,"grants":grants,"ready_plots":plots,"supply_carrot_seeds_added":seed_grant,"crop_worker_paused":worker_paused,"revision":data.revision}
	if apply:
		var backup: String = repo.path("local")+".before-s5-"+str(int(Time.get_unix_time_from_system()))+".bak"
		if FileAccess.get_file_as_string(repo.path("local")).sha256_text() != source_hash or DirAccess.copy_absolute(repo.path("local"),backup) != OK:
			_finish({"ok":false,"error":"Profile changed or backup failed. No write performed."},args[1])
			return
		var written: Dictionary = repo.write_profile("local",data,int(loaded.revision))
		if not written.ok:
			_finish(written,args[1])
			return
		report["applied"] = true
		report["backup"] = backup
		report["reread_ok"] = repo.read_profile("local").ok
	_finish(report,args[1])
