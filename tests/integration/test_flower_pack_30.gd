extends GutTest

const POT: PackedScene = preload("res://scenes/flowers/flower_pot.tscn")
const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_catalog_has_exactly_thirty_species_with_seed_and_sell_links() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres")
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres")
	assert_eq(catalog.flowers.size(), 30)
	assert_true(prices.is_valid())
	var offers: Dictionary = {}
	for offer: ShopOffer in stock.offers:
		if offer.item != null and String(offer.item.item_id).begins_with("flower_"):
			assert_false(offers.has(offer.item.item_id), "No duplicate flower offers")
			offers[offer.item.item_id] = offer
	assert_eq(offers.size(), 30)
	for index: int in range(1, 31):
		var id: String = "flower_%02d" % index
		var seed: ItemDefinition = catalog.items[id + "_seed"]
		var flower: FlowerDefinition = catalog.flowers[id]
		assert_true(flower.is_valid(), id)
		assert_eq(seed.crop, flower)
		assert_eq(flower.harvest_item, catalog.items[id])
		assert_true(offers.has(seed.item_id))
		assert_not_null(prices.find(StringName(id)))
		assert_true(seed.icon.resource_path.contains("flowers48/flower_%02d_" % index))
		assert_eq(flower.harvest_item.icon.get_size(), Vector2(32, 32))
	assert_false(catalog.flowers.has("flower_31"))
	assert_false(catalog.flowers.has("flower_32"))

func test_all_thirty_can_plant_water_mature_and_harvest_new_art() -> void:
	for index: int in range(1, 31):
		var path: String = "res://items/seeds/flower_%02d_seed.tres" % index
		var seed: ItemDefinition = load(path)
		var flower: FlowerDefinition = seed.crop as FlowerDefinition
		var pot: FlowerPot = POT.instantiate() as FlowerPot
		add_child_autofree(pot)
		var bag: InventoryComponent = InventoryComponent.new()
		bag.starting_tools = false
		bag.slot_count = 4
		add_child_autofree(bag)
		bag.add(seed, 1)
		assert_true(pot.plant(bag, 0, 1000.0))
		assert_true(pot.water(1000.0))
		for stage: int in range(5):
			pot.refresh(1000.0 + flower.growth_seconds * float(stage) / 4.0)
			assert_eq(pot.stage, stage)
			assert_eq(pot.sprite.sprite_frames.get_frame_count(&"grow"), 6)
			var texture: Texture2D = pot.sprite.sprite_frames.get_frame_texture(&"grow", 0)
			assert_eq(pot.sprite.position, Vector2(-16, -30))
			if stage >= 3:
				assert_eq(texture.get_size(), Vector2(32, 32))
				assert_eq(texture, flower.harvest_item.icon)
		assert_true(pot.is_mature())
		assert_true(pot.harvest(bag))
		assert_eq(bag.count_item(flower.harvest_item.item_id), flower.harvest_amount)
		assert_null(pot.definition)
		assert_eq(pot.sprite.scale, Vector2.ONE)
		assert_false(pot.sprite.visible)
		assert_eq(pot.visual.pot_sprite.texture.get_size(), Vector2(32, 24))

func test_thirty_species_survive_world_snapshot_restore() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(48)
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
	var garden: FlowerGarden = world.get_node("FlowerGarden") as FlowerGarden
	garden.reset()
	garden.starter_flowers_added = true
	var now: float = world.farming.time_manager.now()
	for index: int in range(1, 31):
		var path: String = "res://flowers/definitions/flower_%02d.tres" % index
		var flower: FlowerDefinition = load(path)
		var cell: Vector2i = Vector2i((index - 1) % garden.Layout.COLUMNS, (index - 1) / garden.Layout.COLUMNS)
		garden.pots[cell].restore_state({"planted_at": now, "growth_started_at": -1.0, "matures_at": 0.0, "progress": 0.0}, flower, now)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("flower_pack_test", 1, now)
	assert_eq(snapshot.flower_gardens[0].flowers.size(), 30)
	var result: Dictionary = adapter.restore(snapshot, now)
	assert_true(result.ok, str(result.get("error")))
	var restored: Dictionary = adapter.capture("flower_pack_test", 2, now)
	var species: Dictionary = {}
	for row: Dictionary in restored.flower_gardens[0].flowers:
		species[row.flower] = true
	assert_eq(species.size(), 30)
	# A completely planted old garden must survive shrinking and another save/load.
	var dense: Dictionary = restored.duplicate(true)
	dense.flower_gardens[0].flowers = []
	for y: int in range(10):
		for x: int in range(18):
			dense.flower_gardens[0].flowers.append({"cell": [x, y], "flower": "flower_01", "planted_at": now-100.0, "growth_started_at": now-100.0, "matures_at": now-1.0, "progress": 1.0})
	result = adapter.restore(dense, now)
	assert_true(result.ok, str(result.get("error")))
	var retained: Dictionary = adapter.capture("flower_pack_test", 3, now)
	assert_eq(retained.flower_gardens[0].flowers.size(), 180)
	result = adapter.restore(retained, now)
	assert_true(result.ok, str(result.get("error")))
	assert_eq(adapter.capture("flower_pack_test", 4, now).flower_gardens[0].flowers.size(), 180)
