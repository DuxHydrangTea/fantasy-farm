extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_pond_has_continuous_water_and_complete_shore_textures() -> void:
	var pond: Node2D = load("res://scenes/objects/outdoor_decor/meadow_pond.tscn").instantiate() as Node2D
	var water: TileMapLayer = pond.get_node("Water") as TileMapLayer
	assert_gt(water.get_used_cells().size(),80)
	for cell: Vector2i in water.get_used_cells():
		var atlas: Vector2i = water.get_cell_atlas_coords(cell)
		var source: TileSetAtlasSource = water.tile_set.get_source(0) as TileSetAtlasSource
		assert_true(source.has_tile(atlas), "Every shore selection exists")
		# Shore tiles sample four corner vertices; a tile with four occupied
		# neighbours can still be a valid concave bank. Check the open centre.
		if Rect2i(138,48,3,3).has_point(cell):
			assert_eq(atlas,Vector2i(1,1),"Interior water must not contain a stray grass edge")
	pond.free()

func test_deep_water_blocks_walking_and_east_path_stays_open() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	await wait_physics_frames(2)
	var navigation: PlayerNavigationComponent = world.player.state.navigation
	var pond: Node2D = world.get_node("MeadowPond") as Node2D
	assert_false(navigation._point_clear(pond.to_global(Vector2(2192,770))), "Player cannot walk into open water")
	assert_true(navigation._segment_clear(Vector2(2376,720),Vector2(2352,820)), "Outer path remains usable")
	assert_true(navigation._point_clear(Vector2(2190,661)), "Picnic approach remains clear")

func test_entire_pond_keeps_clear_of_every_outer_trail_tile() -> void:
	var world: Node2D = WORLD.instantiate() as Node2D
	var water: TileMapLayer = world.get_node("MeadowPond/Water") as TileMapLayer
	var trail: TileMapLayer = world.get_node("EastMeadowDecor/VillageTrail") as TileMapLayer
	var overlaps: Array[String] = []
	for cell: Vector2i in water.get_used_cells():
		# Include the whole bank tile and an 8px grass buffer, not just a
		# convenient straight-line walking sample through the path.
		var bounds: Rect2 = Rect2(water.to_global(water.map_to_local(cell)) - Vector2(8,8),Vector2(16,16)).grow(8)
		for path_cell: Vector2i in trail.get_used_cells():
			var path_bounds: Rect2 = Rect2(trail.to_global(trail.map_to_local(path_cell)) - Vector2(8,8),Vector2(16,16))
			if bounds.intersects(path_bounds):
				overlaps.append(str(cell) + " touches trail " + str(path_cell))
	assert_eq(overlaps.size(),0,str(overlaps))
	world.free()

func test_water_plants_are_fully_inside_open_water() -> void:
	var pond: Node2D = load("res://scenes/objects/outdoor_decor/meadow_pond.tscn").instantiate() as Node2D
	var water: TileMapLayer = pond.get_node("Water") as TileMapLayer
	for node: Node in pond.get_children():
		if not node is Sprite2D or not (str(node.name).begins_with("Reeds") or str(node.name).begins_with("WaterLily")):
			continue
		var sprite: Sprite2D = node as Sprite2D
		var bounds: Rect2 = sprite.get_rect()
		for offset: Vector2 in [Vector2(1,1),Vector2(15,1),Vector2(1,15),Vector2(15,15)]:
			var sample: Vector2 = water.to_local(sprite.to_global(bounds.position + offset))
			assert_eq(water.get_cell_atlas_coords(water.local_to_map(sample)),Vector2i(1,1),str(sprite.name) + " must sit on water, including its entire sprite")
	pond.free()

func test_shore_tree_trunks_stay_on_dry_ground() -> void:
	var world: Node2D = WORLD.instantiate() as Node2D
	var water: TileMapLayer = world.get_node("MeadowPond/Water") as TileMapLayer
	for path: String in ["MeadowPond/SouthWillow", "MeadowPond/BayBirch", "EastMeadowDecor/MeadowOak", "MeadowRestDetails/WestGroveBirch"]:
		var tree: Node2D = world.get_node(path) as Node2D
		assert_eq(water.get_cell_source_id(water.local_to_map(water.to_local(tree.global_position))),-1,path + " trunk stands on land")
	world.free()

func test_meadow_flowers_and_grass_do_not_float_in_the_lake() -> void:
	var world: Node2D = WORLD.instantiate() as Node2D
	var water: TileMapLayer = world.get_node("MeadowPond/Water") as TileMapLayer
	var errors: Array[String] = []
	for path: String in ["EastMeadowDecor", "MeadowRestDetails"]:
		for node: Node in world.get_node(path).get_children():
			var label: String = str(node.name)
			if not node is Sprite2D or not (label.begins_with("MeadowFlower") or label.begins_with("BedGrass") or label.begins_with("LowShrub") or label.begins_with("GrassTuft")):
				continue
			var sprite: Sprite2D = node as Sprite2D
			for offset: Vector2 in [Vector2.ZERO,Vector2(-7,-7),Vector2(7,-7),Vector2(-7,7),Vector2(7,7)]:
				var cell: Vector2i = water.local_to_map(water.to_local(sprite.global_position + offset))
				if water.get_cell_atlas_coords(cell) == Vector2i(1,1):
					errors.append(path + "/" + label)
	assert_eq(errors.size(),0,str(errors))
	world.free()

func test_pond_wildlife_stays_near_shore_and_animates_without_collision() -> void:
	var pond: Node2D = load("res://scenes/objects/outdoor_decor/meadow_pond.tscn").instantiate() as Node2D
	add_child_autofree(pond)
	var water: TileMapLayer = pond.get_node("Water") as TileMapLayer
	var wildlife: Node2D = pond.get_node("Wildlife") as Node2D
	assert_eq(wildlife.get_child_count(), 8)
	assert_true(wildlife.find_children("*", "CollisionObject2D", true, false).is_empty())
	for critter: Node2D in wildlife.get_children():
		if critter is AnimatedSprite2D:
			var capybara: AnimatedSprite2D = critter as AnimatedSprite2D
			assert_true(capybara.is_playing(), str(capybara.name))
			assert_string_contains(capybara.sprite_frames.resource_path, "kapybara_frames.tres")
			assert_eq(capybara.animation, &"idle")
			for corner: Vector2 in [Vector2(-7, -7), Vector2(7, -7), Vector2(-7, 7), Vector2(7, 7)]:
				var cell: Vector2i = water.local_to_map(water.to_local(capybara.global_position + corner))
				assert_eq(water.get_cell_atlas_coords(cell), Vector2i(1, 1), str(capybara.name))
			continue
		var sprite: AnimatedSprite2D = critter.get_node("Sprite") as AnimatedSprite2D
		assert_true(sprite.is_playing(), str(critter.name))
		var route: Vector2 = critter.roam_offset
		if route.is_zero_approx():
			var cell: Vector2i = water.local_to_map(water.to_local(critter.global_position))
			assert_eq(water.get_cell_atlas_coords(cell), Vector2i(1, 1), "Lily frog sits over open water")
			continue
		for step: int in range(5):
			var point: Vector2 = critter.global_position + route * (float(step) / 4.0)
			assert_eq(water.get_cell_source_id(water.local_to_map(water.to_local(point))), -1, str(critter.name))

	var frog: AnimatedSprite2D = wildlife.get_node("WestBankFrog/Sprite") as AnimatedSprite2D
	var croaked: bool = false
	var hopped: bool = false
	for _frame: int in range(150):
		await wait_physics_frames(1)
		croaked = croaked or frog.animation == &"croak_right"
		hopped = hopped or frog.position.y < 0.0
		if croaked and hopped:
			break
	assert_true(croaked, "Frog plays its croak animation")
	assert_true(hopped, "Frog hops after croaking")

func test_land_capybaras_walk_on_the_bank_and_rest() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	var pond: Node2D = world.get_node("MeadowPond") as Node2D
	var trail: TileMapLayer = world.get_node("EastMeadowDecor/VillageTrail") as TileMapLayer
	for bank: String in ["North", "East", "South"]:
		var capybara: Node2D = pond.get_node("Wildlife/" + bank + "BankCapybara") as Node2D
		var sprite: AnimatedSprite2D = capybara.get_node("Sprite") as AnimatedSprite2D
		assert_eq(sprite.sprite_frames.resource_path, "res://sprite_frames/animals/kapybara_land_frames.tres")
		assert_eq(sprite.animation, &"idle")
		for step: int in range(5):
			var point: Vector2 = capybara.global_position + capybara.roam_offset * (float(step) / 4.0)
			assert_eq(trail.get_cell_source_id(trail.local_to_map(trail.to_local(point))), -1, bank)

	var walker: Node2D = pond.get_node("Wildlife/NorthBankCapybara") as Node2D
	var walker_sprite: AnimatedSprite2D = walker.get_node("Sprite") as AnimatedSprite2D
	var start: Vector2 = walker.position
	var destination: Vector2 = start + walker.roam_offset
	var moved: bool = false
	for _frame: int in range(240):
		await wait_physics_frames(1)
		if walker_sprite.animation == &"walk" and walker.position.distance_to(start) > 1.0:
			moved = true
		if moved and walker_sprite.animation == &"idle":
			break
	assert_true(moved, "Capybara moves while the walk clip plays")
	assert_eq(walker_sprite.animation, &"idle")
	assert_eq(walker.position, destination)
