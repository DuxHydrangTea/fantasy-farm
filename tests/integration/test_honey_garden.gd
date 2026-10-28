extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var garden: FlowerGarden
var service: HoneyGardenSystem
var now: float
var clock: Array[float]
var original_clock: Callable
var original_floor: float

func before_each() -> void:
	original_clock = TimeManager.clock_source
	original_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12,4)
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
	world.player.wallet.set_balance(1000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	now = world.farming.time_manager.now()
	clock = [now]
	var manual: Array[float] = clock
	world.farming.time_manager.clock_source = func() -> float: return manual[0]
	garden = world.apiary.gardens[0]
	service = world.honey_garden
	for pot: FlowerPot in garden.pots.values():
		pot.clear()

func after_each() -> void:
	TimeManager.clock_source = original_clock
	TimeManager._last_timestamp = original_floor

func _flower(cell: Vector2i, species: int = 6, ripe: bool = true) -> FlowerPot:
	var pot: FlowerPot = garden.pots[cell]
	var path: String = "res://flowers/definitions/flower_%02d.tres" % species
	var flower: FlowerDefinition = load(path) as FlowerDefinition
	pot.restore_state({"planted_at":now-100,"growth_started_at":now-100,"matures_at":now-1 if ripe else now+100,"progress":1.0 if ripe else 0.5},flower,now)
	return pot

func _hive(slot: int = 1) -> Beehive:
	for hive: Beehive in world.apiary.hives:
		if hive.garden_slot == slot:
			return hive
	return null

func _stand(hive: Beehive) -> void:
	world.player.global_position = hive.global_position + Vector2(0,10)
	world.player.animation.facing_direction = &"up"

func _jump(seconds: float) -> void:
	clock[0] += seconds
	world.apiary.advance(clock[0])

func test_layout_keeps_all_80_pots_and_places_hives_outside_flower_beds() -> void:
	assert_true(service.try_migrate())
	assert_eq(garden.pots.size(),80)
	assert_eq(world.apiary.hives.size(),3)
	assert_true(_hive().repaired)
	assert_false(_hive(0).repaired)
	assert_false(_hive(2).repaired)
	var reserved: int = 0
	var combo: int = 0
	for pot: FlowerPot in garden.pots.values():
		if pot.reserved:
			reserved += 1
		if service.owner_slot(pot.cell) >= 0:
			combo += 1
	assert_eq(reserved,0)
	assert_eq(combo,24)
	for hive: Beehive in world.apiary.hives:
		assert_false(Rect2(Vector2.ZERO, FlowerGarden.SIZE).has_point(garden.to_local(hive.global_position)))
		assert_true(service.inside(hive), "Path hives still open the bee journal")
	assert_true(service.try_migrate())
	assert_eq(world.apiary.hives.size(),3)

func test_center_flower_stays_in_its_pot_when_hives_move_outside() -> void:
	var pot: FlowerPot = _flower(HoneyGardenSystem.CENTERS[1],8,false)
	var original: Dictionary = pot.capture(now)
	assert_true(service.try_migrate())
	assert_not_null(pot.definition)
	var result: Dictionary = pot.capture(now)
	for key: String in ["flower","planted_at","growth_started_at","matures_at","progress"]:
		assert_eq(result[key],original[key])

func test_full_garden_migrates_without_moving_or_losing_flowers() -> void:
	for pot: FlowerPot in garden.pots.values():
		_flower(pot.cell)
	var before: String = JSON.stringify(garden.capture(now))
	assert_true(service.try_migrate())
	assert_eq(JSON.stringify(garden.capture(now)),before)
	assert_eq(world.apiary.hives.size(),3)
	assert_eq(garden.capture(now).flowers.size(),80)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	assert_true(adapter.preflight(adapter.capture("test", 1, clock[0])).ok)

func test_uncollected_legacy_batch_drains_without_restarting_before_migration() -> void:
	var hive: Beehive = world.apiary.create_hive(garden.global_position+Vector2(24,24),&"legacy_hive")
	hive.production.work = hive.definition.cycle_seconds - 10
	_jump(20)
	assert_not_null(hive.production.ready_item)
	assert_false(service.try_migrate())
	assert_true(hive.collect(world.player.selection.inventory))
	_jump(86400)
	assert_eq(hive.production.work,0.0)
	assert_true(service.try_migrate())
	assert_true(hive.repaired)

func test_saved_dense_grid_hives_move_to_new_positions_without_mutating_snapshot() -> void:
	assert_true(service.try_migrate())
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var data: Dictionary = adapter.capture("test", 1, clock[0])
	for row: Dictionary in data.beehives:
		var cell: Vector2i = HoneyGardenSystem.CENTERS[int(row.garden_slot)]
		var point: Vector2 = world.to_local(garden.to_global(Vector2(32 + cell.x * 16, 32 + cell.y * 16)))
		row.position = [point.x, point.y]
	var before: String = JSON.stringify(data)
	var result: Dictionary = adapter.restore(data, clock[0])
	assert_true(result.ok, str(result.get("error")))
	assert_eq(JSON.stringify(data), before)
	for hive: Beehive in world.apiary.hives:
		assert_eq(hive.global_position, service.center_point(hive.garden_slot))

func test_empty_legacy_hive_pauses_but_field_hive_keeps_producing() -> void:
	var old: Beehive = world.apiary.create_hive(garden.global_position+Vector2(24,24),&"old")
	var field: Beehive = world.apiary.create_hive(world.to_global(Vector2(700,600)),&"field")
	_jump(10)
	assert_eq(old.production.work,0.0)
	assert_almost_eq(field.production.work,10.0,0.001)

func test_surplus_hives_refund_whole_items_and_retained_hives_stay_repaired() -> void:
	for i: int in range(5):
		world.apiary.create_hive(garden.global_position+Vector2(16+i*16,16),StringName("old_%d" % i))
	var bag: InventoryComponent = world.player.selection.inventory
	var before: int = bag.count_item(world.apiary.definition.hive_item.item_id)
	assert_true(service.try_migrate())
	assert_eq(world.apiary.hives.size(),3)
	assert_eq(bag.count_item(world.apiary.definition.hive_item.item_id),before+2)
	for hive: Beehive in world.apiary.hives:
		assert_true(hive.repaired)

func test_refund_capacity_defers_all_movement() -> void:
	for i: int in range(4):
		world.apiary.create_hive(garden.global_position+Vector2(16+i*16,16),StringName("old_%d" % i))
	var bag: InventoryComponent = world.player.selection.inventory
	var stacks: Array[Dictionary] = []
	for i: int in range(bag.slot_count):
		stacks.append({"item":InventoryComponent.HOE,"count":1,"tiers":[1,0,0]})
	bag.replace_slots(stacks)
	assert_false(service.try_migrate())
	assert_eq(world.apiary.hives.size(),4)
	assert_false(garden.pots[HoneyGardenSystem.CENTERS[1]].reserved)
	bag.remove_from_slot(5,1)
	assert_true(service.try_migrate())
	assert_eq(bag.count_item(world.apiary.definition.hive_item.item_id),1)

func test_hybrid_requires_opposite_pairs_and_beats_mono_deterministically() -> void:
	var blooms: Dictionary = {Vector2i(-1,0):"flower_01",Vector2i(1,0):"flower_01",Vector2i(0,-1):"flower_06",Vector2i(0,1):"flower_06"}
	assert_eq(HoneyComboCatalog.resolve(blooms),"hybrid_01_06")
	blooms[Vector2i(1,1)] = "flower_06"
	blooms[Vector2i(-1,-1)] = "flower_06"
	assert_eq(HoneyComboCatalog.resolve(blooms),"hybrid_01_06")
	blooms.erase(Vector2i(1,0))
	assert_eq(HoneyComboCatalog.resolve(blooms),"mono_06")
	blooms.erase(Vector2i(1,1))
	assert_eq(HoneyComboCatalog.resolve(blooms),"mixed")
	var two: Dictionary = {Vector2i(-1,0):"flower_02",Vector2i(1,0):"flower_02",Vector2i(0,-1):"flower_07",Vector2i(0,1):"flower_07",Vector2i(1,1):"flower_01",Vector2i(-1,-1):"flower_01",Vector2i(-1,1):"flower_06",Vector2i(1,-1):"flower_06"}
	assert_eq(HoneyComboCatalog.resolve(two),"hybrid_01_06")

func test_fixed_neighbors_snapshot_and_live_rate_fallback() -> void:
	assert_true(service.try_migrate())
	for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		_flower(HoneyGardenSystem.CENTERS[1]+offset)
	_flower(Vector2i(10,2),10)
	_jump(10)
	var hive: Beehive = _hive()
	assert_eq(hive.pollination.source_count,4)
	assert_eq(hive.production.batch_recipe,"mono_06")
	assert_almost_eq(hive.production.work,20.0,0.001)
	for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		garden.pots[HoneyGardenSystem.CENTERS[1]+offset].clear()
	_jump(10)
	assert_almost_eq(hive.production.work,30.0,0.001)
	assert_eq(hive.production.batch_recipe,"mono_06")
	_jump(86400)
	assert_eq(hive.production.ready_item,HoneyComboCatalog.item("mono_06"))
	assert_true(hive.collect(world.player.selection.inventory))
	_jump(1)
	assert_eq(hive.production.batch_recipe,"mixed")

func test_rain_keeps_recipe_and_wind_only_boosts_garden_speed() -> void:
	assert_true(service.try_migrate())
	for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		_flower(HoneyGardenSystem.CENTERS[1]+offset)
	world.weather.set_weather(WeatherSchedule.Weather.RAIN)
	_jump(10)
	assert_eq(_hive().production.batch_recipe,"mono_06")
	assert_almost_eq(_hive().production.work,10.0,0.001)
	world.weather.set_weather(WeatherSchedule.Weather.WINDY)
	var field: Beehive = world.apiary.create_hive(world.to_global(Vector2(700,600)),&"field")
	_jump(10)
	assert_almost_eq(_hive().production.work,35.0,0.001)
	assert_almost_eq(field.production.work,10.0,0.001)
	assert_almost_eq(world.apiary.effective_radius(clock[0]),120.0,0.001)

func test_repair_consumes_warehouse_then_bag_and_cannot_charge_twice() -> void:
	assert_true(service.try_migrate())
	var hive: Beehive = _hive(0)
	_stand(hive)
	var wood: ItemDefinition = load("res://items/trees/wood.tres") as ItemDefinition
	var warehouse: InventoryComponent = world.storages.inventory("produce_warehouse")
	warehouse.add(wood,10)
	world.player.selection.inventory.add(wood,10)
	var coins: int = world.player.wallet.balance
	assert_eq(service.repair(hive),"")
	assert_eq(warehouse.count_item(&"wood"),0)
	assert_eq(world.player.selection.inventory.count_item(&"wood"),5)
	assert_eq(world.player.wallet.balance,coins-500)
	assert_true(hive.repaired)
	assert_false(service.repair(hive).is_empty())
	assert_eq(world.player.wallet.balance,coins-500)

func test_save_roundtrip_carries_recipe_repair_discovery_and_is_idempotent() -> void:
	assert_true(service.try_migrate())
	_jump(10)
	service.discoveries.append("mono_06")
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,catalog)
	var data: Dictionary = adapter.capture("test",1,clock[0])
	var checked: Dictionary = SaveSchema.validate(JSON.parse_string(JSON.stringify(data)),catalog)
	assert_true(checked.ok,str(checked.get("error")))
	assert_true(adapter.preflight(data).ok,str(adapter.preflight(data).get("error")))
	assert_true(adapter.restore(data,clock[0]).ok)
	assert_eq(_hive().production.batch_recipe,"mixed")
	assert_false(_hive(0).repaired)
	assert_eq(service.discoveries,["mono_06"])
	assert_true(service.try_migrate())
	assert_eq(world.apiary.hives.size(),3)

func test_migration_from_v30_is_primitive_only_and_no_batch_is_reclassified() -> void:
	var old: Beehive = world.apiary.create_hive(world.to_global(Vector2(700,600)),&"old_field")
	old.production.advance(100,"flower_06")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("test",1,clock[0])
	data.version = 30
	data.erase("honey_garden")
	for row: Dictionary in data.beehives:
		for key: String in ["batch_recipe","garden_id","garden_slot","repaired"]:
			row.erase(key)
	var before: String = JSON.stringify(data)
	var result: Dictionary = SaveSchema.validate(JSON.parse_string(before),adapter.catalog)
	assert_true(result.ok,str(result.get("error")))
	assert_eq(JSON.stringify(data),before)
	assert_eq(result.snapshot.beehives[0].work,200.0)
	assert_eq(result.snapshot.beehives[0].batch_recipe,"")
	assert_false(result.snapshot.honey_garden.migrated)

func test_five_chef_recipes_reveal_jars_only_after_successful_collection() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var milk: ItemDefinition = load("res://items/animal_produces/cow_milk.tres") as ItemDefinition
	for id: String in HoneyComboCatalog.IDS:
		var recipe: CookingRecipe = ChefCooking.find(id+"_custard")
		assert_not_null(recipe)
		assert_true(recipe.valid())
		bag.add(HoneyComboCatalog.item(id),1)
		bag.add(milk,1)
		assert_eq(world.cooking.start(String(recipe.recipe_id),1,bag,clock[0]),"")
		assert_false(id in service.discoveries)
		clock[0] += recipe.cook_seconds
		assert_eq(world.cooking.collect(bag,clock[0]),1)
		assert_true(id in service.discoveries)

func test_waiting_save_load_offline_marks_hives_before_any_catchup() -> void:
	var point: Vector2 = world.apiary.snap_position(garden.global_position+Vector2(176,120))
	var old: Beehive = world.apiary.create_hive(point,&"waiting")
	old.production.work = old.definition.cycle_seconds-10
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("test",1,clock[0])
	clock[0] += 86400
	var restored: Dictionary = adapter.restore(data,clock[0])
	assert_true(restored.ok,str(restored.get("error")))
	old = world.apiary.hives[0]
	assert_true(old.production.pause_new_batches)
	assert_not_null(old.production.ready_item)
	assert_true(old.collect(world.player.selection.inventory))
	data = adapter.capture("test",2,clock[0])
	clock[0] += 86400
	restored = adapter.restore(data,clock[0])
	assert_true(restored.ok,str(restored.get("error")))
	old = world.apiary.hives[0]
	assert_eq(old.production.work,0.0)
	assert_null(old.production.ready_item)
	assert_true(service.try_migrate())

func test_invalid_garden_batch_or_position_rejects_before_changing_world() -> void:
	assert_true(service.try_migrate())
	_jump(10)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("test",1,clock[0])
	var before: int = world.player.wallet.balance
	var bad: Dictionary = data.duplicate(true)
	bad.beehives[1].batch_recipe = "not_a_recipe"
	assert_false(adapter.restore(bad,clock[0]).ok)
	bad = data.duplicate(true)
	bad.beehives[0].position[0] += 16
	assert_true(adapter.restore(bad,clock[0]).ok, "Fixed hive positions follow trusted scene slots")
	bad = data.duplicate(true)
	bad.beehives[0].garden_slot = 1
	assert_false(adapter.restore(bad,clock[0]).ok)
	assert_eq(world.player.wallet.balance,before)
	assert_eq(world.apiary.hives.size(),3)

func test_failed_repair_is_free_and_damaged_hives_produce_nothing() -> void:
	assert_true(service.try_migrate())
	var hive: Beehive = _hive(0)
	_stand(hive)
	var balance: int = world.player.wallet.balance
	assert_false(service.repair(hive).is_empty())
	assert_eq(world.player.wallet.balance,balance)
	assert_false(hive.repaired)
	_jump(86400)
	assert_eq(hive.production.work,0.0)

func test_repair_blocks_reentrant_commands_and_snapshot_during_notifications() -> void:
	assert_true(service.try_migrate())
	var hive: Beehive = _hive(0)
	_stand(hive)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(load("res://items/trees/wood.tres") as ItemDefinition,30)
	var attempts: Array[String] = []
	var hook: Callable = func() -> void:
		attempts.append(service.repair(hive))
		assert_true(service.busy)
		assert_true(world.storages.busy)
		assert_true(hive.repaired)
	bag.changed.connect(hook,CONNECT_ONE_SHOT)
	assert_eq(service.repair(hive),"")
	assert_eq(attempts.size(),1)
	assert_false(attempts[0].is_empty())
	assert_eq(bag.count_item(&"wood"),15)

func test_pending_legacy_hive_can_load_before_overlapping_pots_are_relocated() -> void:
	_flower(HoneyGardenSystem.CENTERS[1])
	var point: Vector2 = world.apiary.snap_position(garden.pots[HoneyGardenSystem.CENTERS[1]].global_position)
	var old: Beehive = world.apiary.create_hive(point,&"old_layout")
	old.production.work = 10.0
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var data: Dictionary = adapter.capture("test",1,clock[0])
	service.migrated = true # Loading a pending profile must use its DTO, not live flags.
	var result: Dictionary = adapter.restore(data,clock[0])
	assert_true(result.ok,str(result.get("error")))
	assert_false(service.migrated)
	assert_eq(world.apiary.hives[0].production.work,10.0)
	assert_not_null(garden.pots[HoneyGardenSystem.CENTERS[1]].definition)
	assert_false(service.try_migrate())
