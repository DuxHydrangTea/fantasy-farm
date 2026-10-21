extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
const TONIC: ItemDefinition = preload("res://items/boosters/animal_tonic.tres")
var world: FarmWorld
var clock: FarmClock
var now: float = 1000.0
var player: FarmPlayer
var farm: FarmingController
var bag: InventoryComponent
var animal: AnimalActor
var service: BoosterService
var cell: Vector2i = Vector2i(56, 22)

func _set_clocks(node: Node) -> void:
	if node is AnimalNeedsComponent:
		(node as AnimalNeedsComponent).time_manager = clock
	if node is FlowerGarden:
		(node as FlowerGarden).time_manager = clock
	for child: Node in node.get_children():
		_set_clocks(child)

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
	_set_clocks(world)
	add_child_autofree(world)
	player = world.player
	farm = world.farming
	bag = player.selection.inventory
	service = player.boosters.service
	animal = world.get_node("CoopPen").get_children().filter(func(node: Node) -> bool: return node is AnimalActor)[0]
	animal.needs.configure(10000000.0, 10000000.0)
	animal.production.definition = animal.production.definition.duplicate() as AnimalProductionDefinition
	animal.production.definition.production_seconds = 10.0
	animal.production.bonus_roll = func() -> float: return 0.0
	player.position = farm.farmland.map_to_local(cell + Vector2i.UP)
	player.animation.face(Vector2.DOWN)
	bag.add(FERTILIZER, 5)
	bag.add(TONIC, 5)
	bag.move_slot(_slot(FERTILIZER), 4)
	bag.move_slot(_slot(TONIC), 5)
	await wait_physics_frames(2)

func _slot(item: ItemDefinition) -> int:
	for i: int in range(bag.slot_count):
		if bag.slot(i).item == item:
			return i
	return -1

func _crop() -> Crop:
	farm.restore_soil([{"cell": [cell.x, cell.y], "state": 1}])
	var data: CropDefinition = load("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	data.growth_seconds = 100.0
	farm.restore_crop(cell, data, now, now + 100.0, 0.0, now)
	return farm.get_crop(cell)

func test_fertilizer_action_consumes_at_impact_only_and_reschedules_growth() -> void:
	var crop: Crop = _crop()
	player.selection.select_slot(_slot(FERTILIZER))
	assert_true(player.state.use_selected_tool())
	assert_eq(bag.count_item(FERTILIZER.item_id), 5)
	await wait_seconds(0.9)
	assert_true(crop.fertilized)
	assert_eq(crop.matures_at, 1080.0)
	assert_eq(bag.count_item(FERTILIZER.item_id), 4)
	now = 1080.0
	clock.refresh()
	assert_true(crop.is_mature(), "The heap uses the shortened maturity deadline")
	assert_true(player.state.use_selected_tool())
	await wait_seconds(0.9)
	assert_eq(bag.count_item(FERTILIZER.item_id), 4)

func test_cancel_change_slot_reentry_and_locked_plots_do_not_spend_items() -> void:
	var crop: Crop = _crop()
	player.selection.select_slot(_slot(FERTILIZER))
	player.state.use_selected_tool()
	player.selection.select_slot(0)
	await wait_seconds(0.9)
	assert_false(crop.fertilized)
	assert_eq(bag.count_item(FERTILIZER.item_id), 5)
	player.selection.select_slot(_slot(FERTILIZER))
	player.state.use_selected_tool()
	player.state.reset_after_load()
	await wait_seconds(0.9)
	assert_false(crop.fertilized)
	var attempts: Array[Dictionary] = []
	bag.changed.connect(func() -> void: attempts.append(service.use(farm, cell, null, bag, _slot(FERTILIZER), FERTILIZER, player)))
	assert_true(service.use(farm, cell, null, bag, _slot(FERTILIZER), FERTILIZER, player).ok)
	assert_eq(bag.count_item(FERTILIZER.item_id), 4)
	assert_false(attempts[0].ok)
	farm.restore_crop(Vector2i(55, 22), crop.definition, now, now + 100, 0, now)
	assert_false(service.use(farm, Vector2i(55, 22), null, bag, _slot(FERTILIZER), FERTILIZER, player).ok)
	assert_eq(bag.count_item(FERTILIZER.item_id), 4)

func test_tonic_syncs_old_time_halves_maturity_and_does_not_retroactively_produce() -> void:
	animal.growth.configure(86400, 64800, 1209600)
	now += 10
	assert_true(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)
	assert_eq(animal.growth.maturity_seconds, 43200.0)
	assert_eq(animal.growth.age_seconds, 64810.0)
	assert_eq(animal.production.progress_seconds, 0.0)
	assert_null(animal.product_pickup(), "Old juvenile time cannot produce after the dose")
	assert_true(animal.growth.juvenile_tonic_used)
	assert_eq(animal.growth.lifespan_seconds, 1209600.0)
	assert_true(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok, "New adult may receive one production-cycle dose")
	assert_false(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)
	now += 30
	animal.needs.update_at(now)
	assert_eq(animal.product_pickup().amount, 4, "3 cycles plus exactly one bonus")
	assert_false(animal.production.tonic_pending)
	assert_true(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)

func test_juvenile_once_only_and_dead_animal_never_consume_tonic() -> void:
	animal.growth.configure(86400, 0, 1209600)
	assert_true(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)
	assert_false(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)
	assert_eq(bag.count_item(TONIC.item_id), 4)
	animal.growth.configure(86400, 1209600, 1209600)
	assert_false(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)
	assert_eq(bag.count_item(TONIC.item_id), 4)

func test_tonic_action_requires_facing_range_and_unobstructed_target() -> void:
	animal.position = animal.pen.to_local(player.global_position + Vector2(0, 24))
	animal.behaviour.set_focused(true)
	player.selection.select_slot(_slot(TONIC))
	animal.growth.configure(86400, 0, 1209600)
	# Moving an animal outside its pen is only a fixture for near-player targeting.
	animal.wander.set_physics_process(false)
	animal.behaviour.set_physics_process(false)
	player.animation.face(Vector2.UP)
	assert_null(player.boosters.find_animal())
	player.animation.face(Vector2.DOWN)
	assert_eq(player.boosters.find_animal(), animal)
	var blocker: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12, 4)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = player.global_position + Vector2(0, 12)
	world.add_child(blocker)
	await wait_physics_frames(2)
	assert_null(player.boosters.find_animal())
	player.state.use_selected_tool()
	await wait_seconds(0.9)
	assert_eq(bag.count_item(TONIC.item_id), 5, "A wall blocks the tonic without spending it")
	blocker.free()
	await wait_physics_frames(2)
	player.state.use_selected_tool()
	await wait_seconds(0.9)
	assert_eq(bag.count_item(TONIC.item_id), 4)
	assert_true(animal.growth.juvenile_tonic_used)
	animal.global_position = player.global_position + Vector2(0, 80)
	assert_null(player.boosters.find_animal())

func test_v7_disk_roundtrip_preserves_flags_and_consumes_pending_bonus_during_offline() -> void:
	var crop: Crop = _crop()
	assert_true(service.use(farm, cell, null, bag, _slot(FERTILIZER), FERTILIZER, player).ok)
	animal.growth.configure(86400, 90000, 1209600, true)
	assert_true(service.use(farm, cell, animal, bag, _slot(TONIC), TONIC, player).ok)
	animal.persistent_id = &"boosted_animal"
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("booster_test", 1, now)
	# Test crop definition is shortened for the fixture; deadline is persisted directly.
	assert_true(SaveSchema.validate(snapshot, catalog).ok)
	var directory: String = "res://.godot/booster_saves/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repo: LocalSaveRepository = LocalSaveRepository.new(directory, catalog)
	assert_true(repo.write_profile("booster_test", snapshot, 0).ok)
	var loaded: Dictionary = repo.read_profile("booster_test")
	assert_true(loaded.ok)
	var deadline: float = crop.matures_at
	assert_true(adapter.restore(loaded.snapshot, now).ok)
	assert_true(farm.get_crop(cell).fertilized)
	assert_eq(farm.get_crop(cell).matures_at, deadline)
	DirAccess.remove_absolute(repo.path("booster_test"))
	DirAccess.remove_absolute(directory)
	var saved_animal: Dictionary
	for row: Dictionary in loaded.snapshot.animals:
		if row.id == "boosted_animal":
			saved_animal = row
	assert_true(saved_animal.juvenile_tonic_used)
	assert_true(saved_animal.tonic_pending)
	var restored: AnimalActor
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		if node.persistent_id == &"boosted_animal":
			restored = node as AnimalActor
	assert_true(restored.production.tonic_pending)
	assert_eq(restored.growth.maturity_seconds, 43200.0)
	assert_eq(restored.growth.lifespan_seconds, 1209600.0)
	restored.production.bonus_roll = func() -> float: return 0.0
	var duration: float = restored.production.definition.production_seconds
	restored.needs.configure(10000000, 10000000)
	now += duration * 3
	restored.needs.update_at(now)
	assert_false(restored.production.tonic_pending)
	assert_eq(restored.product_pickup().amount, 4)
	var after: Dictionary = adapter.capture("booster_test", 2, now)
	assert_true(adapter.restore(after, now).ok)
	var pile_total: int = 0
	for row: Dictionary in after.pickups:
		if row.item == "chicken_egg":
			pile_total += int(row.amount)
	assert_gte(pile_total, 4)

func test_legacy_migration_and_bad_flags_reject_before_world_changes() -> void:
	_crop()
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var old: Dictionary = adapter.capture("booster_test", 1, now)
	old.version = 6
	old.crops[0].erase("fertilized")
	for row: Dictionary in old.animals:
		row.erase("juvenile_tonic_used")
		row.erase("tonic_pending")
	var original: String = JSON.stringify(old)
	var migrated: Dictionary = SaveSchema.validate(old, catalog)
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.version, SaveSchema.VERSION)
	assert_eq(JSON.stringify(old), original)
	assert_false(migrated.snapshot.crops[0].fertilized)
	var bad: Dictionary = migrated.snapshot.duplicate(true)
	bad.crops[0].fertilized = "yes"
	assert_false(adapter.restore(bad, now).ok)
	bad = migrated.snapshot.duplicate(true)
	bad.animals[0].tonic_pending = true
	bad.animals[0].age = 0
	assert_false(adapter.restore(bad, now).ok)

func test_merchant_sells_canonical_booster_items_with_working_inventory_identity() -> void:
	var catalog: ShopCatalog = load("res://resources/shops/farm_supply.tres")
	var shop: ShopService = ShopService.new(catalog, player.wallet, bag)
	for item: ItemDefinition in [FERTILIZER, TONIC]:
		var found: ShopOffer
		for offer: ShopOffer in catalog.offers:
			if offer.item.item_id == item.item_id:
				found = offer
		assert_not_null(found)
		assert_eq(found.item, item, "Buying and loading use the same external item resource")
		assert_true(shop.buy(found, 2).ok)
		assert_eq(bag.count_item(item.item_id), 7)
