extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const EGG: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
var world: FarmWorld
var now: float = 1793500000.0
var old_source: Callable
var old_floor: float
var old_processing: bool

func before_each() -> void:
	old_source = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	old_processing = TimeManager.is_processing()
	TimeManager.set_process(false)
	TimeManager._last_timestamp = now
	TimeManager.clock_source = func() -> float: return now
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.land.state.restore_blocks(13, 4)
	await wait_physics_frames(2)

func after_each() -> void:
	TimeManager.clock_source = old_source
	TimeManager._last_timestamp = old_floor
	TimeManager.set_process(old_processing)

func _animal(pen_name: String, scene: String) -> AnimalActor:
	var pen: AnimalPen = world.get_node(pen_name) as AnimalPen
	var actor: AnimalActor = load(scene).instantiate() as AnimalActor
	actor.pen = pen
	actor.initial_age_seconds = actor.definition.maturity_seconds + 1
	pen.add_child(actor)
	actor.position = Vector2(80, 96)
	return actor

func test_all_three_pens_accumulate_produce_without_ground_pickups_and_discard_full_batches() -> void:
	for pair: Array in [["CoopPen", "res://scenes/animals/chicken.tscn"], ["BarnPen", "res://scenes/animals/cow.tscn"], ["PondPen", "res://scenes/animals/duck.tscn"]]:
		var actor: AnimalActor = _animal(pair[0], pair[1])
		var store: RefCounted = actor.pen.produce_storage
		var item: ItemDefinition = actor.production.definition.production_item
		store.deposit(item, 2999)
		actor.production.advance(actor.production.definition.production_seconds * 5)
		assert_eq(store.count(), 3000)
		assert_eq(actor.production.stored_amount, 0, "Full pens consume the whole production batch")
		assert_null(actor.product_pickup(), "No new product pile is spawned")
		var bag: InventoryComponent = InventoryComponent.new()
		bag.starting_tools = false
		assert_eq(store.collect(bag), 3000)
		assert_eq(store.count(), 0)
		actor.production.advance(actor.production.definition.production_seconds)
		assert_eq(store.count(), actor.production.definition.production_amount, "Only the next cycle produces after collection")
		bag.free()

func test_building_interaction_collects_and_status_reports_stock_and_free_capacity() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	world.player.state.navigation.set_physics_process(false)
	await wait_physics_frames(2)
	for pair: Array in [["CoopPen", EGG], ["BarnPen", load("res://items/animal_produces/cow_milk.tres")], ["PondPen", load("res://items/animal_produces/duck_egg.tres")]]:
		var pen: AnimalPen = world.get_node(pair[0]) as AnimalPen
		var item: ItemDefinition = pair[1] as ItemDefinition
		pen.produce_storage.deposit(item, 12)
		var access: Node2D = pen.produce_access
		assert_true(access.badge.counts.text.contains("12/3000"))
		assert_true(access.badge.counts.text.contains("2988"))
		assert_eq(access.badge.meter.max_value, 3000.0)
		assert_eq(access.badge.meter.value, 12.0)
		var sprite: Sprite2D = access.interaction_sprite() as Sprite2D
		var label_center: Vector2 = access.badge.get_global_transform() * (access.badge.size * 0.5)
		assert_true(sprite.get_rect().has_point(sprite.to_local(label_center)), "Stock counter is on the building sprite")
		assert_almost_eq(access.global_position.x, sprite.global_position.x, 0.01, "Access is centered at the facade")
		world.player.global_position = access.global_position + Vector2(0, 16)
		var target: InteractionTarget = world.player.interactions.resolver.clicked(sprite.global_position)
		assert_not_null(target, "Clicking the building resolves its collection doorway")
		assert_eq(target.node if target != null else null, access)
		var before: int = world.player.selection.inventory.count_item(item.item_id)
		assert_true(world.player.interactions.execute(target))
		assert_eq(world.player.selection.inventory.count_item(item.item_id), before + 12)
		assert_eq(pen.produce_storage.count(), 0)
		assert_true(access.badge.counts.text.contains("0/3000"))
		assert_eq(access.badge.meter.value, 0.0)
		pen.produce_storage.deposit(item, 1)
		world.player.animation.face(Vector2.UP)
		var keyboard_target: InteractionTarget = world.player.interactions.resolver.resolve()
		assert_eq(keyboard_target.node if keyboard_target != null else null, access)
		assert_true(world.player.interactions.execute(keyboard_target))
		assert_eq(world.player.selection.inventory.count_item(item.item_id), before + 13)

func test_barn_choice_collects_only_the_selected_product_and_updates_meter() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	world.player.state.navigation.set_physics_process(false)
	var milk: ItemDefinition = preload("res://items/animal_produces/cow_milk.tres")
	var wool: ItemDefinition = preload("res://items/animal_produces/sheep_wool.tres")
	var pen: AnimalPen = world.get_node("BarnPen") as AnimalPen
	var access: Node2D = pen.produce_access
	var bag: InventoryComponent = world.player.selection.inventory
	var before: int = bag.count_item(milk.item_id)
	pen.produce_storage.deposit(milk, 25)
	pen.produce_storage.deposit(wool, 2975)
	await wait_physics_frames(2)
	assert_eq(access.badge.meter.value, 3000.0)
	assert_eq(access.badge._icons[0].texture, milk.icon)
	assert_eq(access.badge._icons[1].texture, wool.icon)
	assert_eq(access.badge._amounts[0].text, "25 ×")
	assert_eq(access.badge._amounts[1].text, "2975 ×")
	world.player.global_position = access.global_position + Vector2(0, 16)
	var chip: Control = access.badge._chips[0]
	var point: Vector2 = chip.get_global_transform() * (chip.size * 0.5)
	assert_true(world.player.interactions.click(point))
	assert_false(world.player.selection.is_menu_open())
	assert_eq(bag.count_item(milk.item_id), before + 25)
	assert_eq(pen.produce_storage.capture(), [{"item": "sheep_wool", "amount": 2975}])
	assert_eq(access.badge.meter.value, 2975.0)
	assert_true(access.badge.counts.text.contains("25"))
	assert_eq(access.badge._icons[0].texture, wool.icon)
	assert_eq(access.badge._amounts[0].text, "2975 ×")

func test_clicking_a_distant_building_walks_to_the_door_and_collects() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	world.player.state.navigation.set_physics_process(false)
	await wait_physics_frames(2)
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	pen.produce_storage.deposit(EGG, 7)
	var access: Node2D = pen.produce_access
	world.player.global_position = access.global_position + Vector2(0, 80)
	var before: int = world.player.selection.inventory.count_item(EGG.item_id)
	assert_true(world.player.interactions.click(access.interaction_sprite().global_position))
	for frame: int in range(240):
		world.player.state.navigation.move(1.0 / 60.0)
		await wait_physics_frames(1)
		if not world.player.state.navigation.is_navigating:
			break
	await wait_process_frames(3)
	assert_eq(world.player.selection.inventory.count_item(EGG.item_id), before + 7)
	assert_eq(pen.produce_storage.count(), 0)

func test_worker_candidates_and_commit_collect_from_the_building() -> void:
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	pen.produce_storage.deposit(EGG, 23)
	var task: Dictionary = {"kind": "pen_collect", "id": String(pen.persistent_id), "point": WorkerRole.pair(pen.produce_access.global_position)}
	var bag: InventoryComponent = world.workers.output_inventory()
	var before: int = bag.count_item(EGG.item_id)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(10000000)
	assert_eq(world.workers.hire("crop"), "")
	var row: Dictionary = world.workers.records_for("crop", true)[0]
	var supplies: InventoryComponent = world.workers.feed_inventory(String(row.id))
	var jobs: Array[Dictionary] = world.workers.bridge.candidates(row, supplies)
	var has_job: bool = false
	for job: Dictionary in jobs:
		if job.kind == "pen_collect" and job.id == String(pen.persistent_id):
			has_job = true
			assert_eq(WorkerRole.point(job.point), pen.produce_access.global_position)
	assert_true(has_job, "Workers schedule collection at the real doorway")
	assert_true(world.workers.bridge.commit(row, supplies, task))
	assert_eq(bag.count_item(EGG.item_id), before + 23)
	assert_eq(pen.produce_storage.count(), 0)

func test_offline_worker_schedule_delivers_all_three_pens_to_the_warehouse() -> void:
	var products: Dictionary[String, ItemDefinition] = {
		"CoopPen": EGG,
		"BarnPen": preload("res://items/animal_produces/cow_milk.tres"),
		"PondPen": preload("res://items/animal_produces/duck_egg.tres"),
	}
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(10000000)
	assert_eq(world.workers.hire("crop"), "")
	world.workers.crop_automation.auto_plant = false
	assert_true(world.workers.configure_priority("harvest_first"))
	var output: InventoryComponent = world.workers.output_inventory()
	var expected: Dictionary[String, int] = {}
	for pen_name: String in products:
		var pen: AnimalPen = world.get_node(pen_name) as AnimalPen
		var product: ItemDefinition = products[pen_name]
		expected[pen_name] = output.count_item(product.item_id) + 12
		pen.produce_storage.deposit(product, 12)
	assert_true(world.workers.advance(world.workers.simulated_at + 180.0))
	var row: Dictionary = world.workers.records_for("crop", true)[0]
	for pen_name: String in products:
		var pen: AnimalPen = world.get_node(pen_name) as AnimalPen
		assert_eq(output.count_item(products[pen_name].item_id), expected[pen_name], "%s: %s" % [pen_name, row.task])
		assert_eq(pen.produce_storage.count(), 0, pen_name)

func test_save_restore_keeps_pen_stock_and_does_not_duplicate_on_repeat_load() -> void:
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	pen.produce_storage.deposit(EGG, 3000)
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("pen_storage_test", 1, now)
	assert_true(SaveSchema.validate(snapshot, catalog).ok)
	pen.produce_storage.collect(world.player.selection.inventory)
	var restored: Dictionary = adapter.restore(snapshot, now)
	assert_true(restored.ok, str(restored))
	assert_eq(pen.produce_storage.count(), 3000)
	assert_true(adapter.restore(snapshot, now).ok)
	assert_eq(pen.produce_storage.count(), 3000)

func test_offline_batches_respect_capacity_and_expired_output_never_returns() -> void:
	var actor: AnimalActor = _animal("CoopPen", "res://scenes/animals/chicken.tscn")
	actor.production.definition = actor.production.definition.duplicate(true) as AnimalProductionDefinition
	actor.production.definition.production_seconds = 1
	actor.production.definition.production_amount = 100
	var pen: AnimalPen = actor.pen
	pen.advance_offline(now + 150, true)
	assert_eq(pen.produce_storage.count(), 3000)
	assert_eq(actor.production.stored_amount, 0)
	assert_null(actor.product_pickup())
	pen.produce_storage.collect(world.player.selection.inventory)
	pen.advance_offline(now + 150, true)
	assert_eq(pen.produce_storage.count(), 0, "Same timestamp cannot recover discarded batches")
	pen.advance_offline(now + 155, true)
	assert_eq(pen.produce_storage.count(), 500)

func test_legacy_piles_migrate_into_pen_and_excess_old_goods_are_preserved() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	var snapshot: Dictionary = adapter.capture("pen_migration_test", 1, now)
	snapshot.version = 42
	snapshot.erase("pen_produce")
	snapshot.pickups.append({"id": "legacy_eggs", "pen": String(pen.persistent_id), "position": [80, 100], "item": String(EGG.item_id), "amount": 3020})
	var result: Dictionary = adapter.restore(snapshot, now)
	assert_true(result.ok, str(result))
	assert_eq(pen.produce_storage.count(), 3000)
	var excess: int = 0
	for node: Node in pen.get_children():
		if node is ItemPickup and (node as ItemPickup).item == EGG:
			excess += (node as ItemPickup).amount
	assert_eq(excess, 20, "One-time migration never deletes existing earned items")
	pen.produce_storage.collect(world.player.selection.inventory)
	var migrated: Dictionary = adapter.capture("pen_migration_test", 2, now)
	assert_true(adapter.restore(migrated, now).ok)
	assert_eq(pen.produce_storage.count(), 0, "Reloading a current save does not move legacy excess again")
	assert_eq(adapter.capture("pen_migration_test", 3, now).pickups, migrated.pickups)

func test_bad_saved_pen_stock_is_rejected_before_mutating_the_world() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	pen.produce_storage.deposit(EGG, 12)
	var snapshot: Dictionary = adapter.capture("pen_invalid_test", 1, now)
	for row: Dictionary in snapshot.pen_produce:
		if row.pen == String(pen.persistent_id):
			row.products = [{"item": String(EGG.item_id), "amount": 3001}]
	assert_false(adapter.restore(snapshot, now).ok)
	assert_eq(pen.produce_storage.count(), 12)
