extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var system: TreePlantation

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	system = world.trees

func _cells(kind: TreeDefinition.Kind) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var region: Rect2i = TreePlantation.region_for(kind)
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if TreePlantation.valid_cell(cell, kind):
				result.append(cell)
	return result

func test_all_saved_slots_snap_to_visible_staggered_points_without_losing_capacity() -> void:
	for kind: TreeDefinition.Kind in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var cells: Array[Vector2i] = _cells(kind)
		assert_eq(cells.size(), 153)
		var region: Rect2i = TreePlantation.region_for(kind)
		var origin: Vector2i = region.position + Vector2i(2, 3)
		var a: Vector2 = system.point_for(origin)
		var b: Vector2 = system.point_for(origin + Vector2i(3, 0))
		var next_row: Vector2 = system.point_for(origin + Vector2i(0, 3))
		assert_almost_eq(next_row.x - a.x, (b.x - a.x) * 0.5, 0.001)
		assert_gt(next_row.y, a.y)
		for cell: Vector2i in cells:
			var point: Vector2 = system.point_for(cell)
			assert_eq(system.planting_cell(point, kind), cell, "Marker and planting must use the drawn slot")
			var local: Vector2 = world.farming.farmland.to_local(point)
			var left: float = world.farming.farmland.map_to_local(origin).x
			var last: Vector2i = origin + Vector2i(48, 0)
			var right: float = world.farming.farmland.map_to_local(last).x
			assert_gte(local.x, left)
			assert_lte(local.x, right)

func test_existing_cells_restore_with_same_species_timers_and_new_collider_positions() -> void:
	var now: float = TimeManager.now()
	var expected: Dictionary = {}
	for kind: TreeDefinition.Kind in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var ids: Array[String] = []
		ids.assign(["apple", "peach", "pear", "cherry"] if kind == TreeDefinition.Kind.FRUIT else ["oak", "birch", "spruce"])
		var index: int = 0
		for cell: Vector2i in _cells(kind):
			var definition: TreeDefinition = system.definitions[StringName(ids[index % ids.size()])]
			var tree: PerennialTree = system.create_tree(cell, definition, now)
			if tree is FruitTree:
				(tree as FruitTree).water(now)
			expected[cell] = {"species": definition.tree_id, "deadline": tree.matures_at, "point": tree.global_position}
			index += 1
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("staggered_qa", 1, now)
	assert_eq(saved.trees.size(), 306)
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(system.trees.size(), expected.size())
	for cell: Vector2i in expected:
		var tree: PerennialTree = system.trees[cell]
		assert_eq(tree.definition.tree_id, expected[cell].species)
		assert_eq(tree.matures_at, expected[cell].deadline)
		assert_eq(tree.global_position, expected[cell].point)
		assert_eq(tree.trunk.global_position, tree.global_position + Vector2(0, -3))
		assert_true(world.farming.cell_is_occupied(cell))

func test_planting_and_harvesting_an_offset_row_uses_the_same_target() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var item: ItemDefinition = load("res://items/trees/apple_sapling.tres") as ItemDefinition
	bag.add(item, 1)
	var slot: int = -1
	for index: int in range(bag.slot_count):
		if bag.get_slot_item(index) == item:
			slot = index
	var cell: Vector2i = Vector2i(15, 64)
	var point: Vector2 = system.point_for(cell)
	world.player.global_position = point + Vector2(0, 30)
	world.player.animation.face(Vector2.UP)
	world.player.selection.select_slot(slot)
	await wait_physics_frames(2)
	assert_eq(system.planting_cell(point, TreeDefinition.Kind.FRUIT), cell)
	assert_eq(world.player.tree_interaction.prepare_action(), &"tree_plant")
	var now: float = TimeManager.now()
	var tree: FruitTree = system.plant(cell, bag, slot, item, now) as FruitTree
	assert_not_null(tree)
	if tree == null:
		return
	assert_eq(tree.global_position, point)
	assert_eq(bag.count_item(item.item_id), 0)
	tree.water(now)
	tree.refresh(now + tree.definition.growth_seconds + tree.definition.fruit_cycle_seconds)
	await wait_physics_frames(2)
	var target: InteractionTarget = InteractionTarget.new(tree, InteractionTarget.Kind.TREE, world.player)
	assert_true(target.reachable_from(world.player.global_position))
	assert_true(world.player.interactions.resolver.hit(target, tree.sprite.global_position))
	var before: int = bag.count_item(&"apple")
	world.tool_upgrades.profile_ready = true
	assert_true(world.player.interactions.execute(target))
	assert_true(world.graft_menu.is_open)
	assert_eq(bag.count_item(&"apple"), before, "E/click opens management before harvesting")
	world.graft_menu._collect()
	assert_eq(bag.count_item(&"apple"), before + tree.definition.harvest_amount)
	world.graft_menu.close(false)
