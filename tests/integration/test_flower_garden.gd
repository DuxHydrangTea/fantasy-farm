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
	player.global_position = pot.global_position + Vector2(0, 10)
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

func _pot_position(cell: Vector2i) -> Vector2:
	return garden.to_local(garden.pots[cell].global_position)

func test_grid_is_80_unique_pots_in_four_even_blocks_with_cross_aisle() -> void:
	assert_eq(garden.pots.size(), 80)
	assert_eq(FlowerGarden.SIZE, Vector2(384, 256))
	var used: Dictionary = {}
	for cell: Vector2i in garden.pots:
		var position: Vector2 = _pot_position(cell)
		assert_false(used.has(position))
		used[position] = true
		assert_false(position.x > 176 and position.x < 208)
		assert_false(position.y > 112 and position.y < 144)
	assert_eq(_pot_position(Vector2i(11, 7)), Vector2(352, 234))
	assert_eq(_pot_position(Vector2i(1, 0)) - _pot_position(Vector2i.ZERO), Vector2(32, 0))
	assert_eq(_pot_position(Vector2i(0, 1)) - _pot_position(Vector2i.ZERO), Vector2(0, 22))
	assert_eq(garden.get_node("Floor").get_used_cells().size(), 384)

func test_focus_only_reaches_pot_in_front_and_not_from_far_away() -> void:
	interaction.refresh()
	assert_eq(interaction.focused_pot, pot)
	state.animation.face(Vector2.LEFT)
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
	timestamp = 1000.0 + pot.definition.growth_seconds
	clock.refresh()
	assert_true(pot.is_mature())
	var harvest_amount: int = pot.definition.harvest_amount
	assert_true(state.use_selected_tool(&"harvest"))
	assert_eq(state.active_action, &"flower_harvest")
	_impact()
	assert_null(pot.definition)
	assert_eq(selection.inventory.count_item(&"flower_01"), harvest_amount)

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
	var ready: FlowerPot = garden.pots[Vector2i(11, 0)]
	assert_true(ready.is_mature())
	assert_true(ready.harvest(selection.inventory))
	garden.add_starter_flowers(timestamp)
	assert_null(ready.definition)

func test_four_blocks_share_identical_spacing_and_margins() -> void:
	for row: int in range(4):
		for col: int in range(5):
			var point: Vector2 = _pot_position(Vector2i(col, row))
			assert_eq(_pot_position(Vector2i(col+7, row)) - point, Vector2(192, 0))
			assert_eq(_pot_position(Vector2i(col, row+4)) - point, Vector2(0, 128))
			assert_eq(_pot_position(Vector2i(col+7, row+4)) - point, Vector2(192, 128))
	assert_eq(_pot_position(Vector2i(0, 3)).y, 106.0)
	assert_eq(_pot_position(Vector2i(0, 7)).y, 234.0)

func test_actual_sprite_pixels_stay_inside_authored_block_footprint() -> void:
	var visual_bounds: Rect2 = Rect2()
	var initialized: bool = false
	for index: int in range(1, 31):
		var path: String = "res://flowers/definitions/flower_%02d.tres" % index
		var definition: FlowerDefinition = load(path)
		pot.definition = definition
		for texture: Texture2D in definition.stage_textures:
			pot.visual.show_plant(texture)
			var bounds: Rect2 = pot.get_visual_rect()
			visual_bounds = visual_bounds.merge(bounds) if initialized else bounds
			initialized = true
	for cell: Vector2i in garden.pots:
		var soil: Rect2 = garden.Layout.soil_bounds_for(cell)
		var inner: Rect2 = Rect2(soil.position + Vector2(3, -17), soil.size + Vector2(-6, 10))
		var relative: Transform2D = garden.global_transform.affine_inverse() * garden.pots[cell].global_transform
		var placed: Rect2 = relative * visual_bounds
		assert_true(inner.encloses(placed), "Visible plant/pot pixels cross the bed margin at " + str(cell))

func test_dense_save_preserves_overflow_without_replanting_after_clear() -> void:
	garden.reset()
	garden.starter_flowers_added = true
	var flower: FlowerDefinition = load("res://flowers/definitions/flower_01.tres")
	for y: int in range(10):
		for x: int in range(18):
			var row: Dictionary = {"cell": [x, y], "flower": "flower_01", "planted_at": 900.0, "growth_started_at": 900.0, "matures_at": 950.0, "progress": 1.0}
			garden.restore_flower(row, flower, timestamp)
	garden.restore_legacy_flowers()
	assert_eq(garden.pots.size(), 80)
	assert_eq(garden.capture(timestamp).flowers.size(), 180)
	pot.clear()
	await get_tree().process_frame
	assert_null(pot.definition, "Clearing a pot must not plant a legacy flower")
	assert_false(pot.visual.flower.visible)
	assert_true(pot.visual.pot_sprite.visible)
	assert_eq(garden.capture(timestamp).flowers.size(), 179)
	assert_eq(garden._legacy_flowers.size(), 100, "Unplaced legacy plants remain saved")

func test_e_harvest_with_legacy_overflow_leaves_empty_pot_and_grants_original_flower() -> void:
	garden.reset()
	garden.starter_flowers_added = true
	var flower: FlowerDefinition = load("res://flowers/definitions/flower_01.tres")
	var legacy: FlowerDefinition = load("res://flowers/definitions/flower_02.tres")
	var row: Dictionary = {"cell": [0, 0], "flower": "flower_01", "planted_at": 900.0, "growth_started_at": 900.0, "matures_at": 950.0, "progress": 1.0}
	garden.restore_flower(row, flower, timestamp)
	var overflow: Dictionary = row.duplicate(true)
	overflow.cell = [17, 9]
	overflow.flower = "flower_02"
	garden.restore_flower(overflow, legacy, timestamp)
	var before: int = selection.inventory.count_item(flower.harvest_item.item_id)
	assert_true(state.use_selected_tool(&"harvest"))
	_impact()
	await get_tree().process_frame
	assert_null(pot.definition, "E must leave the harvested pot empty even with legacy overflow")
	assert_false(pot.visual.flower.visible)
	assert_true(pot.visual.pot_sprite.visible)
	assert_eq(selection.inventory.count_item(flower.harvest_item.item_id), before + flower.harvest_amount)
	assert_eq(garden._legacy_flowers.size(), 1)
	var saved: Dictionary = garden.capture(timestamp)
	assert_eq(saved.flowers.size(), 1)
	assert_eq(saved.flowers[0].flower, "flower_02", "The pending flower is preserved without replacing the harvested one")
