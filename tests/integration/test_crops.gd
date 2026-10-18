extends GutTest

const Fixture = preload("res://tests/support/farming_fixture.gd")
const Farming = preload("res://components/farming_controller.gd")
const Clock = preload("res://components/time_manager.gd")
const Item = preload("res://scripts/item_definition.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var field: Node2D
var farming: Farming
var clock: Clock
var player: CharacterBody2D
var state: StateComponent
var timestamp: float = 1000.0
var cell: Vector2i = Vector2i(20, 20)
var target: Vector2i = Vector2i(20, 21)

func before_each() -> void:
	timestamp = 1000.0
	field = Fixture.create_field()
	farming = field.get_node("FarmingController")
	clock = Clock.new()
	clock.clock_source = func() -> float: return timestamp
	farming.time_manager = clock
	add_child_autofree(clock)
	clock.set_process(false)
	add_child_autofree(field)
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = farming.farmland.map_to_local(cell)
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
	assert_eq(farming.get_soil_state(target), Farming.Soil.DRY)

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
	var item: Item = crop.definition.harvest_item
	var amount: int = crop.definition.harvest_amount
	# Fill every free slot with non-stackable tools. Existing seed stack remains full of seeds.
	bag.add(load("res://items/tools/hoe.tres"), 99)
	assert_false(farming.harvest(target, bag))
	assert_not_null(farming.get_crop(target))
	bag.remove(&"hoe", 1)
	assert_true(farming.harvest(target, bag))
	assert_eq(bag.count_item(item.item_id), amount)
	assert_null(farming.get_crop(target))
	assert_eq(farming.get_soil_state(target), Farming.Soil.DRY)
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
