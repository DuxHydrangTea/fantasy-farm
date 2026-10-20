extends GutTest
const GARDEN: PackedScene = preload("res://scenes/flowers/flower_garden.tscn")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var clock: FarmClock
var garden: FlowerGarden
var player: CharacterBody2D
var state: StateComponent
var selection: Node
var interaction: Node
var pot: FlowerPot
var seed_slot: int
var timestamp: float = 1000.0

func before_each() -> void:
	timestamp = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	garden = GARDEN.instantiate() as FlowerGarden
	garden.time_manager = clock
	add_child_autofree(garden)
	player = PLAYER.instantiate() as CharacterBody2D
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	state = player.get_node("StateComponent") as StateComponent
	selection = player.get_node("ToolSelection")
	interaction = player.get_node("FlowerInteraction")
	pot = garden.pots[Vector2i.ZERO]
	player.global_position = pot.global_position + Vector2(0, 20)
	state.animation.face(Vector2.UP)
	var seed: ItemDefinition = load("res://items/seeds/flower_01_seed.tres") as ItemDefinition
	selection.inventory.add(seed, 3)
	for index: int in range(selection.inventory.slot_count):
		if selection.inventory.slot(index).item == seed:
			seed_slot = index
	selection.select_slot(seed_slot)

func _impact() -> void:
	state.animation.animated_sprite.frame = 3
	interaction._on_frame_changed()

func test_grid_is_sixty_unique_pots_in_four_blocks_with_cross_aisle() -> void:
	assert_eq(garden.pots.size(), 60)
	assert_eq(FlowerGarden.SIZE, Vector2(384, 256))
	var used: Dictionary = {}
	for cell: Vector2i in garden.pots:
		var position: Vector2 = garden.pots[cell].position
		assert_false(used.has(position))
		used[position] = true
		assert_false(position.x > 176 and position.x < 208)
		assert_false(position.y > 112 and position.y < 144)
	assert_eq(garden.pots[Vector2i(9, 5)].position, Vector2(352, 224))
	assert_eq(garden.get_node("Floor").get_used_cells().size(), 384)

func test_focus_only_reaches_pot_in_front_and_not_from_far_away() -> void:
	interaction.refresh()
	assert_eq(interaction.focused_pot, pot)
	state.animation.face(Vector2.RIGHT)
	interaction.refresh()
	assert_null(interaction.focused_pot)
	player.position += Vector2(1000, 0)
	interaction.refresh()
	assert_null(interaction.focused_pot)

func test_hotbar_plant_water_and_e_harvest_at_impact_once() -> void:
	assert_eq(state.flower_interaction, interaction)
	assert_true(state.use_selected_tool())
	assert_eq(state.active_action, &"flower_plant")
	assert_null(pot.definition, "No planting before impact")
	_impact()
	assert_not_null(pot.definition)
	assert_eq(selection.inventory.count_item(&"flower_01_seed"), 2)
	_impact()
	assert_eq(selection.inventory.count_item(&"flower_01_seed"), 2)
	state.reset_after_load()
	selection.select_slot(1)
	assert_true(state.use_selected_tool())
	assert_eq(state.active_action, &"flower_water")
	assert_true(pot.can_water())
	_impact()
	assert_false(pot.can_water())
	state.reset_after_load()
	timestamp = 1120.0
	clock.refresh()
	assert_true(pot.is_mature())
	assert_true(state.use_selected_tool(&"harvest"))
	assert_eq(state.active_action, &"flower_harvest")
	_impact()
	assert_null(pot.definition)
	assert_eq(selection.inventory.count_item(&"flower_01"), 1)

func test_move_seed_or_cancel_action_before_impact_does_not_spend_seed() -> void:
	state.use_selected_tool()
	selection.inventory.move_slot(seed_slot, 15)
	_impact()
	assert_null(pot.definition)
	assert_eq(selection.inventory.count_item(&"flower_01_seed"), 3)
	state.reset_after_load()
	selection.inventory.move_slot(15, seed_slot)
	state.use_selected_tool()
	state.reset_after_load()
	_impact()
	assert_null(pot.definition)

func test_inventory_open_blocks_actions_and_hides_focus() -> void:
	selection.set_inventory_open(true)
	interaction.refresh()
	assert_null(interaction.focused_pot)
	assert_false(state.use_selected_tool())
	assert_false(pot.marker.visible)

func test_ten_seed_supplies_are_available_for_new_and_existing_players() -> void:
	var supplies: int = 0
	for child: Node in garden.get_children():
		if child is Area2D:
			supplies += 1
			assert_eq(child.amount, 6)
			assert_true(child.item.item_id.begins_with("flower_"))
	assert_eq(supplies, 10)

func test_eight_starting_flowers_cover_different_stages_and_do_not_respawn() -> void:
	var stages: Dictionary = {}
	var count: int = 0
	for current: FlowerPot in garden.pots.values():
		if current.definition != null:
			count += 1
			stages[current.stage] = true
	assert_eq(count, 8)
	assert_eq(stages.size(), 5)
	var ready: FlowerPot = garden.pots[Vector2i(8, 0)]
	assert_true(ready.is_mature())
	assert_true(ready.harvest(selection.inventory))
	garden.add_starter_flowers(timestamp)
	assert_null(ready.definition)
