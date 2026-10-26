extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const FRUIT: TreeDefinition.Kind = TreeDefinition.Kind.FRUIT
const TIMBER: TreeDefinition.Kind = TreeDefinition.Kind.TIMBER
class RejectState:
	extends TreePlotUpgradeState
	func commit(_kind: TreeDefinition.Kind, _expected: int) -> bool:
		return false
class MemoryRepository:
	extends SaveRepository
	var snapshot: Dictionary = {}
	var writes: int = 0
	var fail_writes: bool = false
	func read_profile(_profile: String) -> Dictionary:
		return {"ok":true, "found":false}
	func write_profile(_profile: String, data: Dictionary, _expected: int) -> Dictionary:
		if fail_writes:
			return SaveSchema.failure("Test IO failure", "io")
		snapshot = data.duplicate(true)
		writes += 1
		return {"ok":true, "revision":data.revision}
var world: FarmWorld
var service: TreePlotUpgradeService

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	service = world.tree_plot_upgrades
	service.profile_ready = true
	world.player.wallet.set_balance(100000000)

func test_each_purchase_unlocks_exactly_nine_more_cells_in_only_one_region() -> void:
	assert_true(service.catalog.valid())
	for kind: TreeDefinition.Kind in [FRUIT, TIMBER]:
		for level: int in range(1, 18):
			var count: int = 0
			var origin: Vector2i = TreePlantation.region_for(kind).position + Vector2i(2,3)
			for x: int in range(17):
				for y: int in range(9):
					if TreePlotUpgradeState.allows(service.state.capture(), origin + Vector2i(x*3,y*3), kind):
						count += 1
			assert_eq(count, level * 9)
			if level < 17:
				var price: int = service.catalog.price(kind, level)
				var coins: int = world.player.wallet.balance
				assert_true(service.purchase(kind, level, price).ok)
				assert_eq(world.player.wallet.balance, coins - price)
		assert_eq(service.quote(kind).code, "max_level")
		if kind == FRUIT:
			assert_eq(service.state.capacity(TIMBER), 9)

func test_locked_plot_does_not_consume_sapling_and_unlocked_plot_can_be_planted() -> void:
	var definition: TreeDefinition = world.trees.definitions[&"apple"]
	var bag: InventoryComponent = world.player.selection.inventory
	var item: ItemDefinition = definition.planting_item()
	bag.add(item, 2)
	var slot: int = -1
	for i: int in range(bag.slot_count):
		if bag.get_slot_item(i) == item:
			slot = i
	assert_gte(slot, 0)
	if slot < 0:
		return
	var count: int = bag.get_slot_count(slot)
	var cell: Vector2i = Vector2i(15,61)
	assert_false(world.trees.can_place(cell, definition, false))
	assert_null(world.trees.plant(cell, bag, slot, item, world.farming.time_manager.now()))
	assert_eq(bag.get_slot_count(slot), count)
	assert_true(service.purchase(FRUIT, 1, 30000).ok)
	assert_true(world.trees.can_place(cell, definition, false))
	await wait_physics_frames(2)
	assert_not_null(world.trees.plant(cell, bag, slot, item, world.farming.time_manager.now()))
	assert_eq(bag.get_slot_count(slot), count - 1)

func test_insufficient_stale_reentry_and_rollback_preserve_coins_and_progress() -> void:
	world.player.wallet.set_balance(29999)
	assert_eq(service.purchase(FRUIT, 1, 30000).code, "insufficient_coins")
	assert_eq(service.state.capacity(FRUIT), 9)
	world.player.wallet.set_balance(100000)
	assert_eq(service.purchase(FRUIT, 1, 1).code, "stale_offer")
	var nested: Array[String] = []
	var callback: Callable = func(_coins: int) -> void:
		nested.append(str(service.purchase(TIMBER, 1, 40000).code))
		assert_eq(service.state.capacity(FRUIT), 18)
		assert_true(service.state.is_busy())
	world.player.wallet.changed.connect(callback)
	assert_true(service.purchase(FRUIT, 1, 30000).ok)
	world.player.wallet.changed.disconnect(callback)
	assert_eq(nested, ["busy"])
	assert_eq(world.player.wallet.balance, 70000)
	assert_eq(service.purchase(FRUIT, 1, 30000).code, "stale_offer")
	service.state = RejectState.new()
	assert_false(service.purchase(FRUIT, 1, 30000).ok)
	assert_eq(world.player.wallet.balance, 70000)
	assert_eq(service.state.capacity(FRUIT), 9)
	service.profile_ready = false
	assert_eq(service.quote(FRUIT).code, "unavailable")

func test_sparse_legacy_migration_uses_farthest_column_and_validates_progress() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var rows: Array = [{"tree":"apple", "cell":[60,85]}]
	assert_eq(TreePlotUpgradeState.migrate(rows,catalog), {"fruit":17,"timber":1})
	assert_eq(TreePlotUpgradeState.migrate([],catalog), TreePlotUpgradeState.fresh())
	for value: Variant in [null, 0, 18, 1.5, "2", INF, NAN]:
		assert_false(TreePlotUpgradeState.valid({"fruit":value,"timber":1}))
	assert_false(TreePlotUpgradeState.valid({"fruit":1,"timber":1,"extra":1}))

func test_save_restore_keeps_paid_empty_plots_and_rejects_tree_on_locked_plot() -> void:
	assert_true(service.purchase(FRUIT, 1, 30000).ok)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var now: float = world.farming.time_manager.now()
	var snapshot: Dictionary = adapter.capture("tree_plot_test",1,now)
	assert_true(SaveSchema.validate(snapshot,adapter.catalog).ok)
	assert_true(adapter.restore(snapshot,now).ok)
	assert_eq(service.state.capacity(FRUIT),18)
	var tree: PerennialTree = world.trees.create_tree(Vector2i(60,85),world.trees.definitions[&"apple"],now)
	var invalid: Dictionary = adapter.capture("tree_plot_test",2,now)
	assert_false(SaveSchema.validate(invalid,adapter.catalog).ok)
	assert_false(adapter.restore(invalid,now).ok)
	assert_eq(world.trees.trees.size(),1)
	var legacy: Dictionary = invalid.duplicate(true)
	legacy.version = 34
	legacy.erase("tree_plot_upgrades")
	var checked: Dictionary = SaveSchema.validate(legacy,adapter.catalog)
	assert_true(checked.ok,str(checked))
	assert_eq(int(checked.snapshot.tree_plot_upgrades.fruit),17)
	assert_eq(checked.snapshot.coins,legacy.coins)
	assert_true(adapter.restore(checked.snapshot,now).ok)
	assert_eq(world.trees.trees.size(),1)
	assert_eq(service.state.capacity(FRUIT),153)
	# Cutting/uprooting never re-locks paid or migrated land.
	tree = world.trees.trees[Vector2i(60,85)]
	world.trees.remove_tree(tree)
	tree.free()
	assert_eq(service.state.capacity(FRUIT),153)
	assert_true(SaveSchema.validate(adapter.capture("tree_plot_test",3,now),adapter.catalog).ok)

func test_purchase_autosaves_and_io_failure_retries_without_charging_again() -> void:
	var manager: GameSaveManager = GameSaveManager.new()
	manager.autosave_seconds = 1000000
	add_child_autofree(manager)
	var repository: MemoryRepository = MemoryRepository.new()
	assert_true((await manager.bind_world(world,repository,"tree_plot_test")).ok)
	assert_true(service.purchase(FRUIT,1,30000).ok)
	await wait_process_frames(3)
	assert_eq(repository.writes,1)
	assert_eq(int(repository.snapshot.tree_plot_upgrades.fruit),2)
	assert_eq(int(repository.snapshot.coins),99970000)
	repository.fail_writes = true
	assert_true(service.purchase(TIMBER,1,40000).ok)
	await wait_process_frames(3)
	assert_eq(manager.revision,1)
	assert_eq(service.state.capacity(TIMBER),18)
	repository.fail_writes = false
	assert_true((await manager.save_game()).ok)
	assert_eq(int(repository.snapshot.tree_plot_upgrades.timber),2)
	assert_eq(int(repository.snapshot.coins),99930000)

func test_actual_legacy_profile_preserves_all_306_trees_and_opens_both_regions_fully() -> void:
	var path: String = "res://docs/pen_upgrades_2026-10-26/legacy_profile.json"
	if not FileAccess.file_exists(path):
		pending("Local profile fixture is optional in clean checkouts")
		return
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var original: Dictionary = JSON.parse_string(str(envelope.payload)) as Dictionary
	var catalog: SaveCatalog = SaveCatalog.new()
	var checked: Dictionary = SaveSchema.validate(original,catalog)
	assert_true(checked.ok,str(checked))
	assert_eq(checked.snapshot.trees,original.trees)
	assert_eq(checked.snapshot.coins,original.coins)
	assert_eq(checked.snapshot.tree_plot_upgrades,{"fruit":17,"timber":17})
	assert_true(WorldStateAdapter.new(world,catalog).restore(checked.snapshot,float(original.saved_at)).ok)
	assert_eq(world.trees.trees.size(),306)
