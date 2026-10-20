extends GutTest

const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_scene_references_are_assigned_before_ready() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	assert_not_null(world.player)
	assert_not_null(world.farming)
	assert_not_null(world.farming.ground)
	var player: FarmPlayer = world.player
	assert_not_null(player.animation)
	assert_not_null(player.state)
	assert_not_null(player.selection)
	assert_not_null(player.camera)
	assert_not_null(player.farming_actions)
	assert_not_null(player.context_bars)
	assert_eq(player.context_bars.player, player)
	assert_eq(player.context_bars.animation, player.animation)
	assert_eq(player.context_bars.actions, player.farming_actions)
	assert_eq(player.context_bars.selection, player.selection)
	assert_eq(player.context_bars.flower_interaction, player.state.flower_interaction)
	assert_eq(player.context_bars.trough_interaction, player.state.trough_interaction)
	assert_not_null(player.state.navigation)
	assert_eq(player.state.navigation.movement, player.state.movement)
	assert_eq(player.state.navigation.animation, player.animation)
	assert_eq(player.state.navigation.camera, player.camera)
	assert_eq(player.state.navigation.farming_actions, player.farming_actions)
	assert_not_null(player.state.navigation.collision_shape)
	assert_not_null(player.state.trough_interaction.prompt)
	assert_not_null(player.state.flower_interaction.prompt)
	assert_eq(player.state.flower_interaction.selection, player.selection)
	assert_eq(player.state.flower_interaction.animation, player.animation)
	assert_eq(player.state.flower_interaction.state, player.state)
	for child: Node in world.get_children():
		if child is PondPen:
			assert_eq((child as PondPen).water_layer, world.farming.farmland)
		if child is AnimalPen:
			for actor: Node in child.get_children():
				if actor is AnimalActor:
					var animal: AnimalActor = actor as AnimalActor
					assert_not_null(animal.sprite)
					assert_not_null(animal.collision)
					assert_not_null(animal.needs_display)
					assert_not_null(animal.satiety_bar)
					assert_not_null(animal.hydration_bar)
					assert_eq(animal.behaviour.wander, animal.wander)
					assert_eq(animal.behaviour.foraging, animal.foraging)
	world.free()

func test_renamed_nodes_keep_gameplay_wiring_and_save_roundtrip() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	var clock: FarmClock = FarmClock.new()
	clock.clock_source = func() -> float: return 1000.0
	clock.set_process(false)
	add_child_autofree(clock)
	world.farming.time_manager = clock
	# Remove editor scatter generators from this deterministic persistence fixture.
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
		elif child is FlowerGarden:
			(child as FlowerGarden).time_manager = clock
		elif child is AnimalPen:
			for actor: Node in child.get_children():
				if actor is AnimalActor:
					(actor as AnimalActor).needs.time_manager = clock
	_rename_nodes(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	await wait_physics_frames(2)
	var player: FarmPlayer = world.player
	assert_eq(player.farming_actions.farming, world.farming)
	assert_eq(player.state.tool_selection, player.selection)
	assert_eq(player.animation.animated_sprite.get_parent(), player)
	var animal: AnimalActor = world.get_tree().get_first_node_in_group(&"animal_status_targets") as AnimalActor
	assert_not_null(animal)
	var mouse: Vector2 = animal.sprite.global_position
	player.context_bars.refresh_at(mouse)
	assert_true(animal.needs_display.visible, "Hover survives renamed scene nodes")
	player.position = Vector2(960, 100)
	player.state.flower_interaction.refresh()
	player.state.trough_interaction.refresh()
	player.context_bars.refresh_at(Vector2.ZERO, false)
	assert_false(animal.needs_display.visible)
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("wiring_test", 1, 1000.0)
	assert_true(SaveSchema.validate(snapshot, catalog).ok)
	assert_eq(snapshot.animals.size(), 47)
	assert_eq(snapshot.flower_gardens.size(), 1)
	player.position += Vector2(16, 0)
	player.selection.select_slot(1)
	assert_true(adapter.restore(snapshot, 1000.0).ok)
	assert_eq(player.position, Vector2(snapshot.player.position[0], snapshot.player.position[1]))
	assert_eq(player.selection.selected_index, int(snapshot.player.selected_slot))
	var restored: Dictionary = adapter.capture("wiring_test", 2, 1000.0)
	assert_eq(restored.animals.size(), snapshot.animals.size())
	assert_eq(restored.pickups.size(), snapshot.pickups.size())
	assert_eq(restored.inventory, snapshot.inventory)

func _rename_nodes(node: Node) -> void:
	for child: Node in node.get_children():
		_rename_nodes(child)
		child.name = "Renamed_" + String(child.name)
