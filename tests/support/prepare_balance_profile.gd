extends "res://tests/support/prepare_s5_profile.gd"
## Adds two complete bulk-cooking samples; leaves existing crops/workers/queues alone.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		get_tree().quit(1)
		return
	catalog = SaveCatalog.new()
	var repo: LocalSaveRepository = LocalSaveRepository.new(args[0],catalog)
	var loaded: Dictionary = repo.read_profile("local")
	if not loaded.ok or not loaded.get("found",false):
		_finish({"ok":false,"error":"Existing profile is unavailable."},args[1])
		return
	var source_hash: String = FileAccess.get_file_as_string(repo.path("local")).sha256_text()
	var apply: bool = args.size() >= 4 and args[2] == "--apply"
	if apply and args[3] != source_hash:
		_finish({"ok":false,"error":"Profile changed after preview."},args[1])
		return
	var data: Dictionary = loaded.snapshot.duplicate(true)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	var bag: InventoryComponent = _bag(data.inventory)
	var grants: Array[Dictionary] = []
	for id: String in ["star_apple_tart_batch","hybrid_01_06_custard_batch"]:
		var recipe: CookingRecipe = ChefCooking.find(id)
		for i: int in range(recipe.ingredients.size()):
			var item: ItemDefinition = recipe.ingredients[i]
			var amount: int = maxi(0,recipe.amounts[i]-bag.count_item(item.item_id))
			if amount > 0:
				if bag.add(item,amount,0,false) != amount:
					_finish({"ok":false,"error":"Not enough bag space. No write performed."},args[1])
					return
				grants.append({"item":String(item.item_id),"amount":amount})
	data.inventory = _rows(bag)
	bag.free()
	data.revision = int(loaded.revision)+1
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,catalog)
	var checked: Dictionary = adapter.preflight(data)
	if not checked.ok:
		_finish(checked,args[1])
		return
	var report: Dictionary = {"ok":true,"applied":false,"source_sha256":source_hash,"grants":grants,"revision":data.revision}
	if apply:
		var backup: String = repo.path("local")+".before-balance-"+str(int(Time.get_unix_time_from_system()))+".bak"
		if FileAccess.get_file_as_string(repo.path("local")).sha256_text() != source_hash or DirAccess.copy_absolute(repo.path("local"),backup) != OK:
			_finish({"ok":false,"error":"Backup failed or source changed."},args[1])
			return
		var result: Dictionary = repo.write_profile("local",data,int(loaded.revision))
		if not result.ok:
			_finish(result,args[1])
			return
		report["applied"] = true
		report["backup"] = backup
		report["reread_ok"] = repo.read_profile("local").ok
	_finish(report,args[1])
