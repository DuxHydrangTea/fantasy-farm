extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const ACTOR: PackedScene = preload("res://scenes/animals/animal.tscn")
var world: FarmWorld
var adapter: WorldStateAdapter
var clock: FarmClock
var timestamp: float
var barn: AnimalPen

func before_each() -> void:
	timestamp = TimeManager.now()
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	clock.set_process(false)
	add_child_autofree(clock)
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	await wait_physics_frames(2)
	world.farming.time_manager = clock
	barn = world.get_node("BarnPen") as AnimalPen
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())
	# Both days sunny; this fixture measures the base 60 units/day exactly.
	for seed_value: int in range(1000):
		world.weather.schedule.seed = seed_value
		if world.weather.schedule.weather_at(timestamp) == WeatherSchedule.Weather.SUNNY and world.weather.schedule.weather_at(timestamp + 86400) == WeatherSchedule.Weather.SUNNY:
			break
	_fill(1200)

func _fill(amount: int) -> void:
	for child: Node in barn.get_children():
		if child is AnimalTrough:
			(child as AnimalTrough).stock = amount
			(child as AnimalTrough).consumed_fraction = 0.0

func _cow(id: String, age: float = 28800.0) -> AnimalActor:
	var actor: AnimalActor = ACTOR.instantiate() as AnimalActor
	actor.definition = preload("res://animals/definitions/cow.tres")
	actor.persistent_id = StringName(id)
	actor.pen = barn
	actor.initial_age_seconds = age
	actor.position = barn.bounds.get_center()
	actor.needs.time_manager = clock
	barn.add_child(actor)
	actor.needs.restore_state(100, 100, timestamp)
	return actor

func _capture() -> Dictionary:
	return adapter.capture("offline_test", 1, timestamp)

func _units(kind: AnimalTrough.Kind) -> float:
	var total: float = 0.0
	for child: Node in barn.get_children():
		if child is AnimalTrough and (child as AnimalTrough).kind == kind:
			total += (child as AnimalTrough).available_units()
	return total

func _output(data: Dictionary, row: Dictionary) -> int:
	var total: int = int(row.production_stock)
	for pile: Dictionary in data.pickups:
		if pile.id == row.pickup:
			total += int(pile.amount)
	return total

func test_load_six_hours_shares_stock_and_repeated_save_load_does_not_duplicate() -> void:
	_cow("cow_a")
	_cow("cow_b")
	var data: Dictionary = _capture()
	timestamp += 21600
	assert_true(adapter.restore(data, timestamp).ok)
	assert_almost_eq(_units(AnimalTrough.Kind.FOOD), 2370.0, 0.00001)
	assert_almost_eq(_units(AnimalTrough.Kind.WATER), 2370.0, 0.00001)
	var after: Dictionary = _capture()
	assert_eq(after.animals.size(), 2)
	for row: Dictionary in after.animals:
		assert_eq(_output(after, row), 100)
		assert_almost_eq(float(row.production_progress), 7200.0, 0.00001)
		assert_eq(row.satiety, 100.0)
	assert_true(adapter.restore(after, timestamp).ok)
	assert_eq(_capture().animals, after.animals)
	assert_eq(_capture().troughs, after.troughs)
	assert_true(SaveSchema.validate(_capture(), adapter.catalog).ok)

func test_runtime_resume_and_refill_cannot_feed_the_past() -> void:
	var actor: AnimalActor = _cow("cow_a")
	_fill(0)
	timestamp += 7200
	var feed: AnimalTrough
	for child: Node in barn.get_children():
		if child is AnimalTrough and (child as AnimalTrough).kind == AnimalTrough.Kind.FOOD:
			feed = child as AnimalTrough
	assert_eq(feed.refill(100), 100)
	assert_almost_eq(actor.production.progress_seconds, 3600.0, 0.00001)
	assert_eq(actor.needs.satiety, 0.0)
	assert_eq(actor.needs.hydration, 0.0)
	assert_almost_eq(feed.available_units(), 100.0, 0.00001)
	clock.refresh()
	assert_almost_eq(actor.production.progress_seconds, 3600.0, 0.00001)
	assert_eq(actor.production.stored_amount, 0)

func test_body_reserves_pause_and_dashboard_explains_missing_food_and_water() -> void:
	var actor: AnimalActor = _cow("cow_a")
	_fill(0)
	actor.needs.restore_state(100, 50, timestamp)
	timestamp += 7200
	clock.refresh()
	assert_almost_eq(actor.production.progress_seconds, 1800.0, 0.00001)
	assert_eq(actor.needs.satiety, 0.0)
	assert_eq(actor.needs.hydration, 0.0)
	var card: AnimalCard = preload("res://scenes/animals/animal_card.tscn").instantiate() as AnimalCard
	card.animal = actor
	add_child_autofree(card)
	assert_string_contains(card.produce.text, tr("Needs food"))
	assert_string_contains(card.produce.text, tr("Needs water"))
	assert_eq(card.food.value, 0.0)
	assert_eq(card.water.value, 0.0)

func test_maturity_crossing_only_credits_adult_time() -> void:
	_cow("calf", 0)
	var data: Dictionary = _capture()
	timestamp += 43200
	assert_true(adapter.restore(data, timestamp).ok)
	var after: Dictionary = _capture()
	assert_eq(_output(after, after.animals[0]), 100)
	assert_almost_eq(float(after.animals[0].production_progress), 0.0, 0.00001)
	assert_almost_eq(_units(AnimalTrough.Kind.FOOD), 2370.0, 0.00001)

func test_death_drops_completed_output_and_capture_includes_new_pile() -> void:
	var actor: AnimalActor = _cow("old_cow", 1209600.0 - 1800.0)
	actor.production.progress_seconds = 13000.0
	timestamp += 7200
	var after: Dictionary = _capture()
	assert_eq(after.animals.size(), 0)
	assert_almost_eq(_units(AnimalTrough.Kind.FOOD), 2398.75, 0.00001)
	var milk: int = 0
	for row: Dictionary in after.pickups:
		if row.item == "cow_milk":
			milk += int(row.amount)
	assert_eq(milk, 100)
	assert_true(SaveSchema.validate(after, adapter.catalog).ok)
	assert_true(adapter.restore(after, timestamp).ok)
	assert_eq(_capture().pickups, after.pickups)

func test_fractional_consumption_survives_many_short_save_cycles() -> void:
	_cow("cow_a")
	var initial: Dictionary = _capture()
	timestamp += 61
	assert_true(adapter.restore(initial, timestamp).ok)
	var first: Dictionary = _capture()
	assert_almost_eq(_units(AnimalTrough.Kind.FOOD), 2400.0 - 61.0 / 1440.0, 0.00001)
	assert_true(first.troughs.any(func(row: Dictionary) -> bool: return float(row.consumed_fraction) > 0.0))
	for iteration: int in range(8):
		var data: Dictionary = _capture()
		timestamp += 61
		assert_true(adapter.restore(data, timestamp).ok)
	var split: Dictionary = _capture()
	assert_true(adapter.restore(initial, timestamp).ok)
	var whole: Dictionary = _capture()
	for index: int in range(split.troughs.size()):
		assert_eq(split.troughs[index].stock, whole.troughs[index].stock)
		assert_almost_eq(float(split.troughs[index].consumed_fraction), float(whole.troughs[index].consumed_fraction), 0.00001)
	assert_almost_eq(float(split.animals[0].production_progress), float(whole.animals[0].production_progress), 0.00001)

func test_v17_migration_preserves_assets_and_rejects_bad_checkpoint_before_mutation() -> void:
	_cow("cow_a")
	var data: Dictionary = _capture()
	data.version = 17
	data.erase("pen_updated_at")
	for row: Dictionary in data.troughs:
		row.erase("consumed_fraction")
	var checked: Dictionary = SaveSchema.validate(data, adapter.catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.animals, data.animals)
	assert_eq(checked.snapshot.coins, data.coins)
	assert_false(data.has("pen_updated_at"))
	assert_true(adapter.restore(data, timestamp).ok)
	var stable: Dictionary = _capture()
	var bad: Dictionary = stable.duplicate(true)
	bad.pen_updated_at[String(barn.persistent_id)] = timestamp - 1
	assert_false(adapter.restore(bad, timestamp).ok)
	bad = stable.duplicate(true)
	bad.troughs[0].consumed_fraction = 1.0
	assert_false(adapter.restore(bad, timestamp).ok)
	assert_eq(_capture().animals, stable.animals)
	assert_eq(_capture().troughs, stable.troughs)

func test_all_seven_adult_species_produce_24_hours_and_use_60_units_each() -> void:
	var initial_food: float = 0.0
	var initial_water: float = 0.0
	for pen: Node in world.get_children():
		if not pen is AnimalPen:
			continue
		for station: Node in pen.get_children():
			if station is AnimalTrough:
				(station as AnimalTrough).stock = 1200
				if (station as AnimalTrough).kind == AnimalTrough.Kind.FOOD:
					initial_food += 1200
				else:
					initial_water += 1200
		for definition: AnimalDefinition in adapter.catalog.animals.values():
			if definition.species not in (pen as AnimalPen).accepted_species:
				continue
			var actor: AnimalActor = ACTOR.instantiate() as AnimalActor
			actor.definition = definition
			actor.persistent_id = StringName("adult_" + String(definition.animal_id))
			actor.initial_age_seconds = definition.maturity_seconds
			actor.pen = pen as AnimalPen
			actor.position = actor.pen.bounds.get_center()
			actor.needs.time_manager = clock
			actor.pen.add_child(actor)
			actor.needs.restore_state(100, 100, timestamp)
	timestamp += 86400
	clock.refresh()
	var after: Dictionary = _capture()
	assert_eq(after.animals.size(), 7)
	for row: Dictionary in after.animals:
		var definition: AnimalDefinition = adapter.catalog.animals[row.animal]
		var batches: int = floori(86400.0 / definition.production.production_seconds)
		assert_eq(_output(after, row), batches * definition.production.production_amount, String(row.animal))
	var food_left: float = 0.0
	var water_left: float = 0.0
	for pen: Node in world.get_children():
		if pen is AnimalPen:
			for station: Node in pen.get_children():
				if station is AnimalTrough:
					if (station as AnimalTrough).kind == AnimalTrough.Kind.FOOD:
						food_left += (station as AnimalTrough).available_units()
					else:
						water_left += (station as AnimalTrough).available_units()
	assert_almost_eq(initial_food - food_left, 420.0, 0.00001)
	assert_almost_eq(initial_water - water_left, 420.0, 0.00001)

func test_buy_after_suspension_does_not_make_newborn_consume_in_the_past() -> void:
	_cow("existing_cow")
	timestamp += 21600
	world.player.wallet.set_balance(100000)
	var shop: ShopCatalog = preload("res://resources/shops/farm_supply.tres")
	var offer: AnimalShopOffer
	for candidate: AnimalShopOffer in shop.animal_offers:
		if candidate.animal.animal_id == &"cow":
			offer = candidate
	var trade: AnimalTradeService = AnimalTradeService.new(shop, world.player.wallet, world, clock)
	assert_true(trade.buy(offer, 1).ok)
	var data: Dictionary = _capture()
	assert_eq(data.animals.size(), 2)
	assert_almost_eq(_units(AnimalTrough.Kind.FOOD), 2385.0, 0.00001)
	for row: Dictionary in data.animals:
		if row.id == "existing_cow":
			assert_eq(_output(data, row), 100)
		else:
			assert_eq(float(row.age), 0.0)
			assert_eq(_output(data, row), 0)
