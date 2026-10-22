extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var farm: FarmingController
var clock: FarmClock
var now: float = 1000.0
var apiary: ApiarySystem
var garden: FlowerGarden
var bag: InventoryComponent
var player: FarmPlayer

func _clocks(node: Node) -> void:
	if node is AnimalNeedsComponent:
		(node as AnimalNeedsComponent).time_manager = clock
	if node is FlowerGarden:
		(node as FlowerGarden).time_manager = clock
	for child: Node in node.get_children():
		_clocks(child)

func before_each() -> void:
	now = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return now
	add_child_autofree(clock)
	clock.set_process(false)
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	world.farming.time_manager = clock
	_clocks(world)
	add_child_autofree(world)
	farm = world.farming
	apiary = world.apiary
	apiary.definition = apiary.definition.duplicate() as BeehiveDefinition
	apiary.definition.cycle_seconds = 100.0
	player = world.player
	bag = player.selection.inventory
	garden = apiary.gardens[0]
	for pot: FlowerPot in garden.pots.values():
		pot.clear()
	world.process_mode = Node.PROCESS_MODE_DISABLED

func _pot(cell: Vector2i, seconds_until_bloom: float = 0, kind: int = 1) -> FlowerPot:
	var pot: FlowerPot = garden.pots[cell]
	var path: String = "res://flowers/definitions/flower_%02d.tres" % kind
	var flower: FlowerDefinition = load(path)
	pot.restore_state({"planted_at":now-120,"growth_started_at":now-120,"matures_at":now+seconds_until_bloom,"progress":1.0 if seconds_until_bloom == 0 else 0.0},flower,now)
	return pot

func _hive(point: Vector2, id: StringName = &"hive_test") -> Beehive:
	var hive: Beehive = apiary.create_hive(point,id)
	apiary.advance(now)
	return hive

func _jump(seconds: float) -> void:
	now += seconds
	clock.refresh()

func test_one_flower_is_assigned_only_to_nearest_hive_and_ties_are_stable() -> void:
	var pot: FlowerPot = _pot(Vector2i(0,0))
	var b: Beehive = _hive(pot.global_position+Vector2(24,0),&"hive_b")
	var a: Beehive = _hive(pot.global_position+Vector2(-24,0),&"hive_a")
	assert_true(a.pollination.active())
	assert_false(b.pollination.active())
	_jump(10)
	assert_almost_eq(a.production.work,13.0,0.00001)
	assert_almost_eq(b.production.work,10.0,0.00001)

func test_offline_bloom_boundary_does_not_apply_pollen_retroactively() -> void:
	var pot: FlowerPot = _pot(Vector2i(0,0),50.0)
	var hive: Beehive = _hive(pot.global_position+Vector2(-24,0))
	_jump(60)
	assert_almost_eq(hive.production.work,63.0,0.00001)
	assert_almost_eq(hive.production.contributions.flower_01,13.0,0.00001)
	_jump(1000)
	assert_eq(hive.production.ready_item,apiary.definition.floral_honey)
	assert_eq(hive.production.work,100.0)

func test_harvesting_flower_keeps_credit_and_continues_as_wild_without_reset() -> void:
	var pot: FlowerPot = _pot(Vector2i(0,0))
	var hive: Beehive = _hive(pot.global_position+Vector2(-24,0))
	now += 20
	assert_true(pot.harvest(bag))
	_jump(20)
	assert_almost_eq(hive.production.work,46.0,0.00001)
	assert_almost_eq(hive.production.contributions.flower_01,26.0,0.00001)
	assert_false(hive.pollination.active())

func test_crop_buff_is_ten_percent_non_stacking_and_fertilizer_uses_original_duration() -> void:
	var cell: Vector2i = Vector2i(56,22)
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(cell))
	var first: FlowerPot = _pot(Vector2i(0,0))
	var second: FlowerPot = _pot(Vector2i(1,0))
	first.global_position = point+Vector2(-30,-30)
	second.global_position = point+Vector2(30,-30)
	_hive(point+Vector2(-30,0),&"hive_a")
	_hive(point+Vector2(30,0),&"hive_b")
	assert_true(farm.till(cell,player))
	var data: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	data.growth_seconds = 100
	farm.restore_crop(cell,data,now,now+100,0,now)
	_jump(20)
	var crop: Crop = farm.get_crop(cell)
	assert_almost_eq(crop.matures_at,1098.0,0.00001)
	assert_almost_eq(crop.pollination_reduction,2.0,0.00001)
	assert_true(farm.fertilize(cell,player))
	assert_almost_eq(crop.matures_at,1078.0,0.00001)
	first.clear()
	second.clear()
	_jump(10)
	assert_almost_eq(crop.matures_at,1078.0,0.00001)

func test_sunflower_maturing_mid_interval_becomes_a_pollen_source() -> void:
	var cell: Vector2i = Vector2i(56,22)
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(cell))
	assert_true(farm.till(cell,player))
	var data: CropDefinition = load("res://crops/field/sunflower/sunflower.tres").duplicate() as CropDefinition
	data.growth_seconds = 50
	farm.restore_crop(cell,data,now,now+50,0,now)
	var hive: Beehive = _hive(point+Vector2(32,0))
	_jump(60)
	assert_almost_eq(hive.production.work,63.0,0.00001)
	assert_eq(hive.pollination.source_id,"sunflower")
	_jump(1000)
	assert_eq(hive.production.ready_item,apiary.definition.sunflower_honey)

func test_placement_is_atomic_spends_one_item_and_rejects_locked_occupied_and_distant_land() -> void:
	var cell: Vector2i = Vector2i(56,22)
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(cell))
	player.position = point+Vector2(0,32)
	bag.add(apiary.definition.hive_item,3)
	bag.move_slot(_slot(&"beehive"),5)
	player.selection.select_slot(5)
	var before: int = bag.count_item(&"beehive")
	var observations: Array[bool] = []
	bag.changed.connect(func() -> void:
		observations.append(apiary.hives.size() == 1)
		assert_false(apiary.place(point,player,5).ok)
	, CONNECT_ONE_SHOT)
	assert_true(apiary.place(point,player,5).ok)
	assert_eq(observations,[true])
	assert_eq(bag.count_item(&"beehive"),before-1)
	assert_false(apiary.place(point,player,5).ok)
	assert_false(apiary.place(point-Vector2(32,0),player,5).ok)
	assert_false(apiary.place(point+Vector2(0,160),player,5).ok)
	assert_eq(bag.count_item(&"beehive"),before-1)
	assert_eq(apiary.hives.size(),1)

func _slot(id: StringName) -> int:
	for index: int in range(bag.slot_count):
		if bag.slot(index).item != null and bag.slot(index).item.item_id == id:
			return index
	return -1

func test_disk_roundtrip_preserves_pollen_offline_bloom_and_ready_honey_without_duplication() -> void:
	apiary.definition.cycle_seconds = 86400.0
	var pot: FlowerPot = _pot(Vector2i(0,0),50)
	var point: Vector2 = _free_near(pot.global_position)
	var hive: Beehive = _hive(point)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var saved: Dictionary = adapter.capture("bees",1,now)
	var folder: String = "res://.godot/bee_saves/"+Crypto.new().generate_random_bytes(8).hex_encode()
	var repo: LocalSaveRepository = LocalSaveRepository.new(folder,SaveCatalog.new())
	assert_true(repo.write_profile("bees",saved,0).ok)
	var loaded: Dictionary = repo.read_profile("bees")
	assert_true(loaded.ok)
	now += 60
	assert_true(adapter.restore(loaded.snapshot,now).ok)
	hive = apiary.hives[0]
	assert_almost_eq(hive.production.work,63.0,0.00001)
	assert_almost_eq(hive.production.contributions.flower_01,13.0,0.00001)
	var halfway: Dictionary = adapter.capture("bees",2,now)
	assert_true(adapter.restore(halfway,now).ok)
	assert_almost_eq(apiary.hives[0].production.work,63.0,0.00001)
	now += 1000000
	assert_true(adapter.restore(halfway,now).ok)
	hive = apiary.hives[0]
	assert_eq(hive.production.ready_item,apiary.definition.floral_honey)
	assert_eq(hive.production.work,86400.0)
	assert_true(hive.collect(bag))
	assert_false(hive.collect(bag))
	assert_eq(bag.count_item(&"floral_honey"),1)
	var emptied: Dictionary = adapter.capture("bees",3,now)
	assert_true(adapter.restore(emptied,now).ok)
	assert_null(apiary.hives[0].production.ready_item)
	assert_eq(bag.count_item(&"floral_honey"),1)
	DirAccess.remove_absolute(repo.path("bees"))
	DirAccess.remove_absolute(folder)

func _free_near(point: Vector2) -> Vector2:
	for y: int in range(-4,5):
		for x: int in range(-4,5):
			var candidate: Vector2 = apiary.snap_position(point+Vector2(x,y)*16)
			if candidate.distance_to(point) <= 80 and apiary.placement_error(candidate).is_empty():
				return candidate
	assert_true(false,"No valid hive position near garden")
	return point

func test_async_disk_roundtrip_accepts_captured_hive_and_keeps_revision_backup() -> void:
	var hive: Beehive = _hive(Vector2(888, 360))
	hive.production.work = 25.0
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var folder: String = "res://.godot/bee_saves/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repo: LocalSaveRepository = LocalSaveRepository.new(folder, SaveCatalog.new())
	var first: Dictionary = adapter.capture("bees", 1, now)
	var written: Dictionary = await repo.write_profile_async("bees", first, 0)
	assert_true(written.ok, str(written.get("error", "")))
	if written.ok:
		hive.production.work = 50.0
		var second: Dictionary = adapter.capture("bees", 2, now)
		var updated: Dictionary = await repo.write_profile_async("bees", second, 1)
		assert_true(updated.ok, str(updated.get("error", "")))
		var loaded: Dictionary = await repo.read_profile("bees")
		assert_true(loaded.ok)
		assert_eq(int(loaded.snapshot.revision), 2)
		assert_eq(float(loaded.snapshot.beehives[0].work), 50.0)
		var previous: Dictionary = repo._read(repo.path("bees") + ".bak", "bees")
		assert_true(previous.ok)
		assert_eq(int(previous.snapshot.revision), 1)
		assert_eq(float(previous.snapshot.beehives[0].work), 25.0)
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(repo.path("bees") + suffix):
			DirAccess.remove_absolute(repo.path("bees") + suffix)
	DirAccess.remove_absolute(folder)

func test_invalid_honey_or_placement_rejects_the_whole_load_and_v8_migrates_without_reset() -> void:
	apiary.definition.cycle_seconds = 86400.0
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var saved: Dictionary = adapter.capture("bees",1,now)
	var old: Dictionary = saved.duplicate(true)
	old.version = 8
	old.erase("beehives")
	var checked: Dictionary = SaveSchema.validate(old,adapter.catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.version,SaveSchema.VERSION)
	assert_eq(checked.snapshot.beehives,[])
	assert_false(old.has("beehives"))
	var pot: FlowerPot = _pot(Vector2i(0,0))
	_hive(_free_near(pot.global_position))
	saved = adapter.capture("bees",1,now)
	var before: int = player.wallet.balance
	for bad: Variant in [-1,"100",INF]:
		var broken: Dictionary = saved.duplicate(true)
		broken.beehives[0].work = bad
		broken.coins = 0
		assert_false(adapter.restore(broken,now).ok)
		assert_eq(player.wallet.balance,before)
	var broken: Dictionary = saved.duplicate(true)
	broken.beehives[0].position = [0,0]
	assert_false(adapter.restore(broken,now).ok)
	assert_eq(apiary.hives.size(),1)
	broken = saved.duplicate(true)
	broken.beehives[0].contributions = {"flower_01":1.0}
	assert_false(adapter.restore(broken,now).ok)
	broken = saved.duplicate(true)
	broken.beehives.append(broken.beehives[0].duplicate(true))
	assert_false(adapter.restore(broken,now).ok)

func test_unified_e_click_priority_collection_and_honey_sale() -> void:
	var hive: Beehive = _hive(_free_near(garden.pots[Vector2i(0,0)].global_position))
	hive.production.advance(100,"")
	player.position = hive.global_position+Vector2(0,24)
	player.animation.face(Vector2.UP)
	player.interactions.refresh()
	assert_eq(player.interactions.focused.node,hive)
	assert_eq(player.interactions.focused.priority(),1)
	assert_eq(player.interactions.presenter.outline.get_parent(),hive.sprite)
	assert_true(hive.range_display.visible)
	assert_string_contains(player.interactions.presenter.label.text,"Collect Wild Honey")
	assert_true(player.interactions.press())
	assert_eq(bag.count_item(&"wild_honey"),1)
	assert_null(hive.production.ready_item)
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres")
	var sale: ProduceSaleService = ProduceSaleService.new(prices,player.wallet,bag)
	var before: int = player.wallet.balance
	assert_true(sale.sell(prices.find(&"wild_honey"),1).ok)
	assert_eq(player.wallet.balance,before+150)
	var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	merchant.position = player.position+Vector2(24,-8)-merchant.interaction_offset
	player.animation.face(Vector2.RIGHT)
	player.interactions.refresh()
	assert_eq(player.interactions.focused.node,merchant)
	assert_false(hive.range_display.visible)

func test_click_approaches_a_full_hive_and_collects_only_on_arrival() -> void:
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(Vector2i(56,22)))
	var hive: Beehive = _hive(point)
	hive.production.advance(100,"")
	player.position = point+Vector2(0,112)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	await wait_physics_frames(3)
	assert_true(player.interactions.click(hive.sprite.global_position))
	assert_eq(bag.count_item(&"wild_honey"),0)
	await wait_seconds(3)
	assert_eq(bag.count_item(&"wild_honey"),1)
	assert_null(player.interactions.pending)
	assert_lte(player.position.distance_to(hive.global_position),32.0)

func test_bought_hive_can_be_placed_by_left_click_without_navigation() -> void:
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres")
	var offer: ShopOffer
	for entry: ShopOffer in stock.offers:
		if entry.item == apiary.definition.hive_item:
			offer = entry
	assert_not_null(offer)
	assert_eq(offer.price,1500)
	player.wallet.set_balance(3000)
	assert_true(ShopService.new(stock,player.wallet,bag).buy(offer,1).ok)
	bag.move_slot(_slot(&"beehive"),5)
	player.selection.select_slot(5)
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(Vector2i(56,22)))
	player.position = point+Vector2(0,32)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = player.get_canvas_transform()*point
	player.state._unhandled_input(event)
	assert_eq(apiary.hives.size(),1)
	assert_eq(bag.count_item(&"beehive"),0)
	assert_false(player.state.navigation.is_navigating)
	assert_eq(player.wallet.balance,1500)

func test_pollination_saving_keeps_reduction_and_replays_offline_growth_once() -> void:
	apiary.definition.cycle_seconds = 86400.0
	farm.land.restore_columns(48)
	var pot: FlowerPot = _pot(Vector2i(0,0))
	garden.global_position += Vector2(904,312)-pot.global_position
	var cell: Vector2i = Vector2i(53,22)
	assert_true(farm.till(cell,player))
	var data: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	data.growth_seconds = 100
	farm.restore_crop(cell,data,now,now+100,0,now)
	_hive(Vector2(888,360))
	_jump(20)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world,SaveCatalog.new())
	var saved: Dictionary = adapter.capture("bees",1,now)
	await wait_physics_frames(2)
	now += 20
	assert_true(adapter.restore(saved,now).ok)
	var crop: Crop = farm.get_crop(cell)
	assert_almost_eq(crop.pollination_reduction,4.0,0.00001)
	assert_almost_eq(crop.matures_at,1096.0,0.00001)
	var repeated: Dictionary = adapter.capture("bees",2,now)
	assert_true(adapter.restore(repeated,now).ok)
	assert_almost_eq(farm.get_crop(cell).matures_at,1096.0,0.00001)
	assert_true(farm.fertilize(cell,player))
	assert_almost_eq(farm.get_crop(cell).matures_at,1076.0,0.00001)

func test_continuous_pollination_does_not_append_stage_heap_entries_each_tick() -> void:
	var cell: Vector2i = Vector2i(56,22)
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(cell))
	var pot: FlowerPot = _pot(Vector2i(0,0))
	pot.global_position = point+Vector2(0,-32)
	_hive(point+Vector2(24,0))
	assert_true(farm.till(cell,player))
	var data: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	data.growth_seconds = 1000
	farm.restore_crop(cell,data,now,now+1000,0,now)
	var initial: int = farm._growth._heap.size()
	for index: int in range(100):
		now += 0.1
		apiary.advance(now)
	assert_lte(farm._growth._heap.size(),initial+1)
	assert_almost_eq(farm.get_crop(cell).pollination_reduction,1.0,0.00001)

func test_bees_culling_keeps_notifier_visible_and_wakes_both_flying_sprites() -> void:
	var hive: Beehive = _hive(Vector2(1608,408))
	var visual: BeeVisualComponent = hive.bees
	var notifier: VisibleOnScreenNotifier2D = visual.get_child(2) as VisibleOnScreenNotifier2D
	assert_true(visual.is_visible_in_tree(),"The notifier's parent must stay visible while bees are culled")
	assert_true(notifier.is_visible_in_tree())
	assert_false(visual.is_processing())
	visual._visibility(true)
	assert_true(visual.is_processing())
	assert_eq(visual._bees.size(),2)
	var first_position: Vector2 = visual._bees[0].position
	for bee: AnimatedSprite2D in visual._bees:
		assert_true(bee.is_visible_in_tree())
		assert_true(bee.is_playing())
	visual._process(0.2)
	assert_ne(visual._bees[0].position,first_position)
	visual._visibility(false)
	assert_true(notifier.is_visible_in_tree(),"Culling must not hide its own wake-up sensor")
	assert_false(visual.is_processing())
	for bee: AnimatedSprite2D in visual._bees:
		assert_false(bee.visible)
		assert_false(bee.is_playing())
	visual._visibility(true)
	for bee: AnimatedSprite2D in visual._bees:
		assert_true(bee.is_visible_in_tree())
		assert_true(bee.is_playing())
