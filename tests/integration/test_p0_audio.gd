extends GutTest
const Fixture = preload("res://tests/support/farming_fixture.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
var field: Node2D
var farm: FarmingController
var player: FarmPlayer
var events: Array[StringName] = []
var old_clock: Callable
var tick: int = 10000
var origin: Vector2i = Vector2i(11, 21)

func before_each() -> void:
	events.clear()
	tick = 10000
	old_clock = Sound.clock
	Sound.clock = func() -> int: return tick
	field = Fixture.create_field()
	add_child_autofree(field)
	farm = field.get_node("FarmingController") as FarmingController
	player = PLAYER.instantiate() as FarmPlayer
	player.position = farm.farmland.map_to_local(origin)
	player.farming_actions.farming = farm
	field.add_child(player)
	await wait_physics_frames(2)
	player.state.set_physics_process(false)
	player.audio_feedback.set_physics_process(false)
	Sound.stop_all()
	Sound.sound_played.connect(_played)

func after_each() -> void:
	Sound.sound_played.disconnect(_played)
	Sound.stop_all()
	Sound.clock = old_clock

func _played(event: StringName, _stream: AudioStream) -> void:
	events.append(event)

func _impact(action: StringName, cell: Vector2i) -> void:
	player.animation.face(Vector2.DOWN)
	player.state.current_state = StateComponent.State.WATER if action == &"water" else StateComponent.State.TOOL
	player.state.active_action = action
	player.farming_actions._cell = cell
	player.farming_actions._targets = [cell]
	player.farming_actions._action = action
	player.animation.play("water" if action == &"water" else "tool", true)
	player.animation.animated_sprite.stop()
	player.animation.animated_sprite.frame = 3
	player.farming_actions._on_frame_changed()

func test_soil_and_water_only_sound_after_a_successful_impact_once() -> void:
	var cell: Vector2i = origin + Vector2i.DOWN
	Fixture.mark_cell(field, cell)
	_impact(&"tool", cell)
	assert_eq(farm.get_soil_state(cell), FarmingController.Soil.DRY)
	assert_eq(events, [&"till_soil"])
	player.farming_actions._on_frame_changed()
	assert_eq(events.size(), 1)
	tick += 1000
	_impact(&"tool", cell)
	assert_eq(events.size(), 1)
	_impact(&"water", cell)
	assert_eq(events, [&"till_soil", &"water_crop"])

func test_real_harvest_plays_one_cue_and_inventory_restore_is_silent() -> void:
	var cell: Vector2i = origin + Vector2i.DOWN
	Fixture.mark_cell(field, cell)
	farm.till(cell)
	var bag: InventoryComponent = player.selection.inventory
	bag.add(SEED, 1)
	var slot: int = -1
	for index: int in range(bag.slot_count):
		if bag.slot(index).item == SEED:
			slot = index
			break
	assert_true(farm.plant(cell, bag, slot, player))
	var crop: Crop = farm.get_crop(cell)
	crop.progress = 1.0
	assert_true(farm.harvest(cell, bag))
	assert_eq(events, [&"harvest_crop"])
	bag.changed.emit()
	assert_eq(events.size(), 1)
	assert_false(farm.harvest(cell, bag))
	assert_eq(events.size(), 1)

func test_walking_uses_actual_distance_and_rejects_walls_menus_and_teleports() -> void:
	var audio: PlayerAudioFeedback = player.audio_feedback
	player.state.current_state = StateComponent.State.WALK
	var point: Vector2 = player.global_position
	audio.advance_position(point)
	assert_eq(events.size(), 0)
	audio.advance_position(point + Vector2(19, 0))
	assert_eq(events.size(), 1)
	tick += 1000
	audio.advance_position(point + Vector2(500, 0))
	assert_eq(events.size(), 1)
	player.selection.set_shop_open(true)
	audio.advance_position(point + Vector2(520, 0))
	assert_eq(events.size(), 1)
	player.selection.set_shop_open(false)
	player.state.current_state = StateComponent.State.IDLE
	audio.advance_position(point + Vector2(540, 0))
	assert_eq(events.size(), 1)

func test_capacity_reports_and_large_pickups_do_not_make_one_sound_per_item() -> void:
	var item: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
	player.item_feedback._on_pickup(item, 1000)
	player.item_feedback._on_pickup(item, 1000)
	assert_eq(events, [&"collect_egg"])
	player.item_feedback._on_capacity_blocked(item, 1000, 0)
	player.item_feedback._on_capacity_blocked(item, 1000, 0)
	assert_eq(events, [&"collect_egg", &"error_capacity"])

func _world() -> FarmWorld:
	var world: FarmWorld = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(2000000)
	return world

func test_livestock_purchase_and_rejected_purchase_have_distinct_transaction_sounds() -> void:
	var world: FarmWorld = _world()
	var merchant: ShopMerchant = world.get_node("PetMerchant") as ShopMerchant
	var shop: ShopUI = merchant.shop_ui
	assert_true(shop.open(merchant, world.player))
	shop.show_category(ShopOffer.Category.ANIMAL)
	Sound.stop_all()
	events.clear()
	var price: int = shop.selected_animal_offer.price
	shop.purchase()
	assert_eq(world.player.wallet.balance, 2000000 - price)
	assert_eq(events, [&"coin_spend"])
	world.player.wallet.set_balance(0)
	tick += 1000
	shop.purchase()
	assert_eq(events, [&"coin_spend", &"error_resources"])
	shop.close(false)

func test_order_delivery_sounds_once_and_does_not_replay_on_refresh() -> void:
	var world: FarmWorld = _world()
	world.land.state.restore_blocks(24)
	world.orders.service.fill_empty()
	var serial: int = int(world.orders.service.capture().slots[0].serial)
	var entry: OrderDefinition = world.orders.service.definition(serial)
	for index: int in range(entry.items.size()):
		world.player.selection.inventory.add(entry.items[index], entry.amounts[index])
	world.player.global_position = world.orders.global_position + Vector2(0, 24)
	assert_true(world.orders.open_board(world.player))
	var menu: OrderUI = world.orders.menu
	menu._request("deliver")
	Sound.stop_all()
	events.clear()
	menu._confirm()
	assert_eq(events, [&"order_delivered"])
	menu._refresh()
	menu._confirm()
	assert_eq(events, [&"order_delivered"])
	menu.close(false)

func test_actual_stone_road_and_dirt_field_paths_use_different_materials() -> void:
	var world: FarmWorld = _world()
	var road: TileMapLayer = world.get_node("Road") as TileMapLayer
	var point: Vector2 = road.to_global(road.map_to_local(road.get_used_cells()[0]))
	assert_eq(world.player.audio_feedback.surface_event(point), &"footstep_stone")
	for layer_name: String in ["FarmLand", "FieldBoundaries"]:
		var layer: TileMapLayer = world.get_node(layer_name) as TileMapLayer
		var checked: bool = false
		for cell: Vector2i in layer.get_used_cells():
			if layer_name == "FarmLand":
				var tile: TileData = layer.get_cell_tile_data(cell)
				if tile == null or not tile.has_custom_data("can_till") or tile.get_custom_data("can_till") != true:
					continue # FarmLand also contains unplantable outer grass/water tiles.
			point = layer.to_global(layer.map_to_local(cell))
			if road.get_cell_source_id(road.local_to_map(road.to_local(point))) >= 0:
				continue
			assert_eq(world.player.audio_feedback.surface_event(point), &"footstep_dirt", layer_name)
			checked = true
			break
		assert_true(checked, "Need a real dirt sample from " + layer_name)

func test_tilled_and_wet_crop_soil_override_pavement_underneath() -> void:
	var cell: Vector2i = origin + Vector2i.DOWN
	Fixture.mark_cell(field, cell)
	assert_true(farm.till(cell))
	var road: TileMapLayer = field.get_node("Road") as TileMapLayer
	var sample: Vector2i = road.get_used_cells()[0]
	var point: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(cell))
	var road_cell: Vector2i = road.local_to_map(road.to_local(point))
	road.set_cell(road_cell, road.get_cell_source_id(sample), road.get_cell_atlas_coords(sample), road.get_cell_alternative_tile(sample))
	assert_eq(player.audio_feedback.surface_event(point), &"footstep_dirt")
	assert_true(farm.water(cell))
	assert_eq(player.audio_feedback.surface_event(point), &"footstep_dirt")
