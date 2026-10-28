extends GutTest

const GARDEN: PackedScene = preload("res://scenes/flowers/flower_garden.tscn")
const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_all_80_pots_are_serialized_and_registration_is_idempotent() -> void:
	var garden: FlowerGarden = GARDEN.instantiate() as FlowerGarden
	assert_eq(garden.get_node("Pots").get_child_count(), 4)
	for block: Node in garden.get_node("Pots").get_children():
		assert_eq(block.get_child_count(), 20)
	assert_true(garden._get_configuration_warnings().is_empty())

	assert_true(garden.pots.is_empty(), "Scene nodes exist before registration")
	add_child_autofree(garden)
	assert_eq(garden.pots.size(), 80)
	var first: FlowerPot = garden.pots[Vector2i.ZERO]
	var connections: int = first.changed.get_connections().size()
	garden._register_pots(garden.pot_container)
	assert_eq(garden.pots.size(), 80)
	assert_eq(first.changed.get_connections().size(), connections)
	for block: Node in garden.get_node("Pots").get_children():
		assert_eq(block.get_child_count(), 20)

func test_duplicate_missing_and_invalid_cell_configuration_is_reported() -> void:
	var garden: FlowerGarden = GARDEN.instantiate() as FlowerGarden
	var pot: FlowerPot = garden.get_node("Pots/BlockTopLeft/Pot_00_00") as FlowerPot
	pot.cell = Vector2i(1, 0)
	assert_true("; ".join(garden._get_configuration_warnings()).contains("Duplicate pot cell"))
	pot.cell = Vector2i(99, 99)
	assert_true("; ".join(garden._get_configuration_warnings()).contains("outside the authored layout"))
	pot.free()
	assert_true("; ".join(garden._get_configuration_warnings()).contains("found 79"))
	garden.free()

func test_custom_node_and_block_transforms_survive_scene_pack_and_startup() -> void:
	var authored: FlowerGarden = GARDEN.instantiate() as FlowerGarden
	var pot: FlowerPot = authored.get_node("Pots/BlockTopLeft/Pot_00_00") as FlowerPot
	var block: Node2D = authored.get_node("Pots/BlockBottomRight") as Node2D
	pot.position += Vector2(5, -2)
	pot.visual.plant_offset.position = Vector2(2, -3)
	block.position += Vector2(-4, 2)
	var skin: PotDefinition = pot.pot_definition.duplicate() as PotDefinition
	skin.pot_id = &"scene_custom"
	pot.pot_definition = skin
	var position: Vector2 = pot.position
	var block_position: Vector2 = block.position
	var packed: PackedScene = PackedScene.new()
	assert_eq(packed.pack(authored), OK)
	authored.free()
	var loaded: FlowerGarden = packed.instantiate() as FlowerGarden
	add_child_autofree(loaded)
	var restored: FlowerPot = loaded.pots[Vector2i.ZERO]
	assert_eq(restored.position, position)
	assert_eq(loaded.get_node("Pots/BlockBottomRight").position, block_position)
	assert_eq(restored.visual.plant_offset.position, Vector2(2, -3))
	assert_eq(restored.pot_definition.pot_id, &"scene_custom")
	assert_eq(loaded.pots.size(), 80)
	restored.refresh(1000.0)
	assert_eq(restored.position, position)
	assert_eq(restored.visual.plant_offset.position, Vector2(2, -3))

func test_fixed_hives_stay_on_path_after_moving_flower_blocks() -> void:
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
	assert_true(world.honey_garden.try_migrate())
	var now: float = world.farming.time_manager.now()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("scene_custom", 1, now)
	var before: String = JSON.stringify(snapshot)
	var block: Node2D = garden.get_node("Pots/BlockTopLeft") as Node2D
	block.position += Vector2(2, 0)
	var cell: Vector2i = HoneyGardenSystem.CENTERS[0]
	garden.pots[cell].position += Vector2(1, 0)
	var expected: Vector2 = garden.pots[cell].global_position
	assert_eq(world.honey_garden.center_point(0), garden.to_global(HoneyGardenSystem.HIVE_POSITIONS[0]))
	var result: Dictionary = adapter.restore(snapshot, now)
	assert_true(result.ok, str(result.get("error")))
	assert_eq(JSON.stringify(snapshot), before)
	assert_eq(garden.pots[cell].global_position, expected)
	for hive: Beehive in world.apiary.hives:
		assert_eq(hive.global_position, world.honey_garden.center_point(hive.garden_slot))
		assert_eq(hive.range_display.garden, garden)

func test_clicking_tall_flower_head_and_pot_body_resolves_the_same_slot() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.starter_content.begin_restore(true)
	world.starter_content.finish_restore()
	var garden: FlowerGarden = world.get_node("FlowerGarden") as FlowerGarden
	garden.reset()
	garden.starter_flowers_added = true
	var pot: FlowerPot = garden.pots[Vector2i(4, 3)]
	var flower: FlowerDefinition = load("res://flowers/definitions/flower_04.tres")
	var now: float = garden.time_manager.now()
	pot.restore_state({"planted_at": now-100, "growth_started_at": now-100, "matures_at": now-1, "progress": 1.0}, flower, now)
	var resolver: InteractionResolver = world.player.interactions.resolver
	var point: Vector2 = pot.to_global(Vector2(0, -39))
	assert_gt(pot.global_position.distance_to(point), 36.0)
	var target: InteractionTarget = resolver.clicked(point)
	assert_not_null(target)
	if target != null:
		assert_eq(target.node, pot)
	target = resolver.clicked(pot.to_global(Vector2(0, -10)))
	assert_not_null(target)
	if target != null:
		assert_eq(target.node, pot)
	world.player.interactions.presenter.show_target(InteractionTarget.new(pot, InteractionTarget.Kind.FLOWER, world.player), false)
	assert_true(world.player.interactions.presenter.badge.visible)
	var presenter: InteractionPresenter = world.player.interactions.presenter
	var original_position: Vector2 = presenter.badge.position
	pot.motion.target.rotation += 0.2
	presenter.show_target(InteractionTarget.new(pot, InteractionTarget.Kind.FLOWER, world.player), false)
	assert_eq(presenter.badge.position, original_position, "Plant motion must not move the interaction tooltip")
	var original_anchor: Vector2 = pot.to_global(presenter._plant_anchor)
	pot.position += Vector2(20, 0)
	presenter.show_target(InteractionTarget.new(pot, InteractionTarget.Kind.FLOWER, world.player), false)
	assert_true(pot.to_global(presenter._plant_anchor).is_equal_approx(original_anchor + Vector2(20, 0)), "The anchor still follows the object's world position")
	assert_not_null(pot.visual.pot_sprite.get_node_or_null("InteractionPotOutline"))
