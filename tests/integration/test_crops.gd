extends GutTest

const Fixture = preload("res://tests/support/farming_fixture.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var field: Node2D
var farming: FarmingController
var clock: FarmClock
var player: CharacterBody2D
var state: StateComponent
var timestamp: float = 1000.0
var cell: Vector2i = Vector2i(20, 20)
var target: Vector2i = Vector2i(20, 21)

func before_each() -> void:
	timestamp = 1000.0
	field = Fixture.create_field()
	farming = field.get_node("FarmingController")
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	farming.time_manager = clock
	add_child_autofree(clock)
	clock.set_process(false)
	add_child_autofree(field)
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = farming.farmland.map_to_local(cell)
	(player as FarmPlayer).farming_actions.farming = farming
	field.add_child(player)
	state = player.get_node("StateComponent")
	Fixture.mark_cell(field, target)
	await wait_physics_frames(2)
	assert_true(farming.till(target, player))

func test_plant_spends_one_seed_at_impact_only_once() -> void:
	state.tool_selection.select_slot(2)
	var before: int = state.tool_selection.inventory.slot(2).count
	watch_signals(farming)
	assert_true(state.use_selected_tool())
	await wait_physics_frames(2)
	assert_null(farming.get_crop(target))
	assert_eq(state.tool_selection.inventory.slot(2).count, before)
	await wait_seconds(0.9)
	assert_not_null(farming.get_crop(target))
	assert_eq(state.tool_selection.inventory.slot(2).count, before - 1)
	assert_signal_emit_count(farming, "crop_planted", 1)
	assert_false(farming.can_plant(target, player))
	assert_true(farming.can_water(target, player), "A crop does not block watering its soil")
	assert_true(farming.water(target, player))

func test_rejected_planting_preserves_seed_count() -> void:
	var bag: Node = state.tool_selection.inventory
	var before: int = bag.slot(2).count
	assert_false(farming.plant(target + Vector2i.RIGHT, bag, 2, player))
	assert_false(farming.plant(target, bag, 0, player), "Tools are not seeds")
	assert_true(farming.plant(target, bag, 2, player))
	assert_false(farming.plant(target, bag, 2, player), "Cannot replace an existing crop")
	assert_eq(bag.slot(2).count, before - 1)

func test_cancel_or_moved_seed_before_impact_does_not_spend_seed() -> void:
	state.tool_selection.select_slot(2)
	assert_true(state.use_selected_tool())
	player.get_node("InventoryUI").open()
	await wait_seconds(0.8)
	assert_null(farming.get_crop(target))
	assert_eq(state.tool_selection.inventory.slot(2).count, 12)
	player.get_node("InventoryUI").close()
	assert_true(state.use_selected_tool())
	state.tool_selection.inventory.move_slot(2, 7)
	await wait_seconds(0.8)
	assert_null(farming.get_crop(target))
	assert_eq(state.tool_selection.inventory.slot(7).count, 12)

func test_switching_hotbar_mid_action_keeps_original_seed_and_target() -> void:
	state.tool_selection.select_slot(2)
	assert_true(state.use_selected_tool())
	state.tool_selection.select_slot(1)
	await wait_seconds(0.9)
	assert_not_null(farming.get_crop(target))
	assert_eq(state.tool_selection.inventory.slot(2).count, 11)
	assert_eq(farming.get_soil_state(target), FarmingController.Soil.DRY)

func test_clock_tick_updates_independent_crops_and_progress() -> void:
	var bag: Node = state.tool_selection.inventory
	assert_true(farming.plant(target, bag, 2, player))
	var first: Node = farming.get_crop(target)
	timestamp += first.definition.growth_seconds / 3.0
	clock.refresh()
	var other: Vector2i = target + Vector2i.RIGHT
	Fixture.mark_cell(field, other)
	assert_true(farming.till(other, player))
	assert_true(farming.plant(other, bag, 2, player))
	assert_eq(first.stage, 1)
	assert_almost_eq(first.progress_bar.value, 1.0 / 3.0, 0.0001)
	assert_eq(farming.get_crop(other).stage, 0)
	timestamp += 10000.0
	clock.refresh()
	assert_true(first.is_mature())
	assert_true(farming.get_crop(other).is_mature())

func test_harvest_requires_maturity_and_capacity_then_keeps_soil() -> void:
	var bag: Node = state.tool_selection.inventory
	assert_true(farming.plant(target, bag, 2, player))
	assert_false(farming.harvest(target, bag))
	var crop: Node = farming.get_crop(target)
	timestamp = crop.matures_at
	var item: ItemDefinition = crop.definition.harvest_item
	var amount: int = crop.definition.harvest_amount
	# Fill every free slot with non-stackable tools. Existing seed stack remains full of seeds.
	bag.add(load("res://items/tools/hoe.tres"), 99)
	assert_false(farming.harvest(target, bag))
	assert_not_null(farming.get_crop(target))
	bag.remove(&"hoe", 1)
	assert_true(farming.harvest(target, bag))
	assert_eq(bag.count_item(item.item_id), amount)
	assert_null(farming.get_crop(target))
	assert_eq(farming.get_soil_state(target), FarmingController.Soil.DRY)
	assert_true(farming.can_plant(target, player))
	assert_false(farming.harvest(target, bag))

func test_e_key_harvests_at_animation_impact() -> void:
	assert_true(farming.plant(target, state.tool_selection.inventory, 2, player))
	timestamp = farming.get_crop(target).matures_at
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	state._unhandled_input(event)
	await wait_physics_frames(2)
	assert_not_null(farming.get_crop(target))
	await wait_seconds(0.9)
	assert_null(farming.get_crop(target))

func test_crop_anchor_tracks_scaled_translated_land() -> void:
	field.position = Vector2(100, 70)
	field.scale = Vector2(2, 2)
	assert_true(farming.plant(target, state.tool_selection.inventory, 2, player))
	var expected: Vector2 = farming.farmland.to_global(farming.farmland.map_to_local(target) + Vector2(0, 8))
	assert_eq(farming.get_crop(target).global_position, expected)
	assert_eq(farming.get_crop(target).global_scale, Vector2(2, 2))

func test_harvest_reward_rises_from_soil_and_failed_harvest_shows_nothing() -> void:
	var bag: InventoryComponent = state.tool_selection.inventory
	assert_true(farming.plant(target, bag, 2, player))
	assert_false(farming.harvest(target, bag))
	assert_eq(get_tree().get_nodes_in_group(&"item_gain_popups").size(), 0)

	var crop: Crop = farming.get_crop(target)
	var produce: ItemDefinition = crop.definition.harvest_item
	var quantity: int = crop.definition.harvest_amount
	timestamp = crop.matures_at
	var reentry: Array[bool] = []
	bag.changed.connect(func() -> void: reentry.append(farming.harvest(target, bag)), CONNECT_ONE_SHOT)
	assert_true(farming.harvest(target, bag))
	assert_eq(reentry, [false])
	var effects: Array[Node] = get_tree().get_nodes_in_group(&"item_gain_popups")
	assert_eq(effects.size(), 1)
	var popup: ItemGainPopup = effects[0] as ItemGainPopup
	assert_eq(popup.item, produce)
	assert_eq(popup.amount, quantity)
	assert_eq(popup.global_position, farming.farmland.to_global(farming.farmland.map_to_local(target)))
	assert_eq(popup.get_parent(), field)
	assert_eq((player as FarmPlayer).item_feedback.get_child_count(), 0)
	assert_false(popup.visible)
	await wait_seconds(0.35)
	assert_true(popup.visible)
	await wait_seconds(1.05)
	assert_eq(get_tree().get_nodes_in_group(&"item_gain_popups").size(), 0)

func test_simultaneous_pickup_and_harvest_rewards_keep_separate_lines() -> void:
	var bag: InventoryComponent = state.tool_selection.inventory
	assert_true(farming.plant(target, bag, 2, player))
	var crop: Crop = farming.get_crop(target)
	timestamp = crop.matures_at
	var origin: Vector2 = farming.farmland.to_global(farming.farmland.map_to_local(target))
	player.position = origin + Vector2(0, 34)
	var feedback: ItemGainFeedback = (player as FarmPlayer).item_feedback
	feedback.collector.item_acquired.emit(crop.definition.harvest_item, 1)
	var head: ItemGainPopup = feedback.get_child(0) as ItemGainPopup
	assert_almost_eq(head.global_position.y, origin.y, 0.01)
	assert_true(farming.harvest(target, bag))
	assert_lte(head.global_position.y, origin.y - 28.0)

func test_harvest_burst_never_adds_a_second_yield_and_load_clears_transient_visuals() -> void:
	var bag: InventoryComponent = state.tool_selection.inventory
	assert_true(farming.plant(target, bag, 2, player))
	var crop: Crop = farming.get_crop(target)
	var produce: ItemDefinition = crop.definition.harvest_item
	var amount: int = crop.definition.harvest_amount
	timestamp = crop.matures_at
	assert_true(farming.harvest(target, bag))
	assert_eq(bag.count_item(produce.item_id), amount)

	assert_null(farming.get_crop(target))
	assert_true(crop.is_retiring())
	assert_eq(farming.crop_cells().size(), 0)
	var bursts: Array[Node] = get_tree().get_nodes_in_group(&"harvest_effects")
	assert_eq(bursts.size(), 2, "One retiring plant and one visual produce burst")
	assert_eq(get_tree().get_nodes_in_group(&"item_pickups").size(), 0)
	(player as FarmPlayer).item_feedback.clear()
	farming.restore_soil([])
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group(&"harvest_effects").size(), 0)
	assert_eq(bag.count_item(produce.item_id), amount)


func test_all_22_crops_harvest_through_action_impact_with_correct_yield(crop_name = use_parameters([
	"beetroot", "bell_pepper", "broccoli", "cabbage", "carrot", "chili_pepper",
	"corn", "cucumber", "eggplant", "garlic", "green_bell_pepper", "leek", "onion",
	"parsnip", "potato", "pumpkin", "radish", "strawberry", "sunflower", "tomato", "wheat", "yellow_bell_pepper"
])) -> void:
	var crop_path: String = "res://crops/field/%s/%s.tres" % [crop_name, crop_name]
	var definition: CropDefinition = load(crop_path) as CropDefinition
	farming.restore_crop(target, definition, timestamp - 20.0, timestamp - 1.0, 1.0, timestamp)
	var bag: InventoryComponent = state.tool_selection.inventory
	assert_true(farming.can_harvest(target))
	assert_gte(bag.capacity_for(definition.harvest_item), definition.harvest_amount)
	watch_signals(farming)
	assert_true(state.use_selected_tool(&"harvest"))
	await wait_seconds(0.9)
	assert_null(farming.get_crop(target))
	assert_eq(bag.count_item(definition.harvest_item.item_id), definition.harvest_amount)
	assert_signal_emit_count(farming, "harvest_yielded", 1)
	assert_eq(farming.get_soil_state(target), FarmingController.Soil.DRY)

func test_full_bag_reports_capacity_problem_and_preserves_mature_crop() -> void:
	var bag: InventoryComponent = state.tool_selection.inventory
	var definition: CropDefinition = load("res://crops/field/wheat/wheat.tres") as CropDefinition
	farming.restore_crop(target, definition, timestamp - 20.0, timestamp - 1.0, 1.0, timestamp)
	bag.add(load("res://items/tools/hoe.tres"), 100)
	watch_signals(bag)
	assert_false(farming.harvest(target, bag))
	assert_signal_emitted_with_parameters(bag, "capacity_blocked", [definition.harvest_item, definition.harvest_amount, 0])
	assert_not_null(farming.get_crop(target))
	assert_eq(bag.count_item(definition.harvest_item.item_id), 0)
	var feedback: ItemGainFeedback = (player as FarmPlayer).item_feedback
	assert_eq(feedback.get_child_count(), 1)
	var notice: ItemGainPopup = feedback.get_child(0) as ItemGainPopup
	assert_eq(notice.message, "Túi đồ đầy")
	bag.remove(&"hoe", 1)
	assert_true(farming.harvest(target, bag))
	assert_eq(bag.count_item(definition.harvest_item.item_id), definition.harvest_amount)
