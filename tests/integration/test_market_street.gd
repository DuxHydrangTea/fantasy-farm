extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld

func test_walking_dust_remains_visible_above_the_road() -> void:
	var road: TileMapLayer = world.get_node("Road") as TileMapLayer
	var dust: GPUParticles2D = world.player.state.dust_particles
	assert_gte(world.player.z_index + dust.z_index, road.z_index, "Walking dust must draw above the paved road")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	for start: Vector2 in [Vector2(400, 232), Vector2(2048, 320)]:
		world.player.global_position = start
		world.player.state.touch_direction = Vector2.RIGHT
		await wait_physics_frames(10)
		assert_gt(world.player.global_position.x, start.x, "Player walks on the surface")
		assert_true(dust.emitting, "Walking emits dust on road and grass")
		world.player.state.touch_direction = Vector2.ZERO
		await wait_physics_frames(15)
		assert_false(dust.emitting, "Stopping stops new dust")

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_blocks(13, 4)
	await wait_physics_frames(2)

func test_main_street_reaches_every_merchant_and_opens_the_correct_menu() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.set_physics_process(false)
	var navigation: PlayerNavigationComponent = world.player.state.navigation
	var road: TileMapLayer = world.get_node("Road") as TileMapLayer
	for path: String in ["LaiBuon", "FlowerMerchant", "Chef", "PetMerchant", "ProduceBuyer", "BlacksmithMerchant"]:
		var merchant: ShopMerchant = world.get_node(path) as ShopMerchant
		var approach: Vector2 = merchant.interaction_position() + Vector2(0,24)
		var start: Vector2 = Vector2(approach.x,232)
		assert_ne(road.get_cell_source_id(road.local_to_map(road.to_local(start))), -1, path + " connects to the main road")
		assert_true(navigation._segment_clear(start, approach), path + " has an unobstructed player-width approach")
		world.player.global_position = approach
		world.player.animation.face(merchant.interaction_position() - approach)
		await wait_physics_frames(2)
		assert_true(merchant.open_shop(world.player), path + " opens from its new location")
		assert_true(merchant.menu.is_open, path + " menu is visible")
		merchant.menu.close(false)
		await wait_process_frames(2)

func test_shop_order_and_storehouse_locations_are_preserved() -> void:
	var last_x: float = -INF
	for path: String in ["SeedFlowerShop", "FlowerShop", "House1", "PetShop", "BlacksmithShop"]:
		var building: Node2D = world.get_node(path) as Node2D
		assert_gt(building.position.x, last_x, "Shops follow the intended west-to-east order")
		assert_lt(building.position.y, 208.0, "Shopfronts stay north of the road")
		last_x = building.position.x
	assert_eq((world.get_node("Warehouse") as Node2D).position, Vector2(2100,1148))
	assert_eq((world.get_node("SeedInventory") as Node2D).position, Vector2(2340,1148))

func test_sparrows_perch_until_player_approaches_then_land_farther_away() -> void:
	var flock: Node2D = world.get_node("StorageYard/Sparrows") as Node2D
	assert_eq(flock.get_child_count(), 3)
	assert_true(flock.find_children("*", "CollisionObject2D", true, false).is_empty())
	world.player.state.set_physics_process(false)
	world.player.state.navigation.set_physics_process(false)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	var bird: AnimatedSprite2D = flock.get_node("WestSparrow") as AnimatedSprite2D
	var origin: Vector2 = bird.position
	world.player.global_position = bird.global_position + Vector2(0, 96)
	await wait_physics_frames(18)
	assert_eq(bird.position, origin)
	assert_eq(bird.animation, &"idle")
	world.player.global_position = bird.global_position + bird.approach_offset
	var flew: bool = false
	for _frame: int in range(100):
		await wait_physics_frames(1)
		flew = flew or (bird.animation == &"fly" and bird.position.y < origin.y)
		if flew and bird.animation == &"idle":
			break
	assert_true(flew, "An approaching player makes the bird take off")
	assert_eq(bird.animation, &"idle")
	assert_eq(bird.position, bird.alternate_perches[-1], "Bird lands on the perch farthest from the player")

func test_shop_cat_stretches_and_orchard_squirrels_remain_visible() -> void:
	var cat: Node2D = world.get_node("PetShop/ShopCat") as Node2D
	var cat_sprite: AnimatedSprite2D = cat.get_node("Sprite") as AnimatedSprite2D
	var squirrel: Node2D = world.get_node("OrchardDecor/NortheastSquirrel") as Node2D
	var squirrel_sprite: AnimatedSprite2D = squirrel.get_node("Sprite") as AnimatedSprite2D
	var southwest_squirrel: Node2D = world.get_node("OrchardDecor/SouthwestSquirrel") as Node2D
	for animal: Node2D in [cat, squirrel, southwest_squirrel]:
		assert_true(animal.find_children("*", "CollisionObject2D", true, false).is_empty())
	assert_eq(cat_sprite.animation, &"idle")
	assert_eq(squirrel_sprite.animation, &"idle")
	var cat_home: Vector2 = cat.position
	var squirrel_home: Vector2 = squirrel.position
	var southwest_home: Vector2 = southwest_squirrel.position
	world.process_mode = Node.PROCESS_MODE_INHERIT
	var stretched: bool = false
	var ran: bool = false
	var stayed_visible: bool = true
	var reached_away: bool = false
	var southwest_reached_away: bool = false
	var returned: bool = false
	var southwest_returned: bool = false
	for _frame: int in range(540):
		await wait_physics_frames(1)
		stretched = stretched or cat_sprite.animation == &"stretch"
		ran = ran or (squirrel_sprite.animation == &"walk" and squirrel.position.distance_to(squirrel_home) > 1.0)
		stayed_visible = stayed_visible and squirrel.is_visible_in_tree() and southwest_squirrel.is_visible_in_tree()
		reached_away = reached_away or squirrel.position.is_equal_approx(squirrel_home + squirrel.roam_offset)
		southwest_reached_away = southwest_reached_away or southwest_squirrel.position.is_equal_approx(southwest_home + southwest_squirrel.roam_offset)
		returned = returned or (reached_away and squirrel.position.is_equal_approx(squirrel_home))
		southwest_returned = southwest_returned or (southwest_reached_away and southwest_squirrel.position.is_equal_approx(southwest_home))
		if stretched and ran and returned and southwest_returned and cat_sprite.animation == &"idle" and cat.position != cat_home:
			break
	assert_true(stretched, "The cat stretches before changing nap spots")
	assert_eq(cat.position, cat_home + cat.roam_offset)
	assert_eq(cat_sprite.animation, &"idle")
	assert_true(ran)
	assert_true(stayed_visible, "Both squirrels stay visible throughout the round trip")
	assert_true(returned)
	assert_true(southwest_returned)

func test_east_square_joins_the_road_with_a_clear_paved_approach() -> void:
	var road: TileMapLayer = world.get_node("Road") as TileMapLayer
	var yards: TileMapLayer = world.get_node("BuildingDecor/ShopForecourts") as TileMapLayer
	for x: int in range(115,121):
		assert_ne(road.get_cell_source_id(Vector2i(x,28)), -1, "The square has continuous paving")
	assert_eq(yards.get_cell_atlas_coords(Vector2i(121,28)), Vector2i(1,1), "No grass seam at the paving-to-soil transition")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.set_physics_process(false)
	var navigation: PlayerNavigationComponent = world.player.state.navigation
	assert_true(navigation._segment_clear(Vector2(1848,456), Vector2(1944,456)), "Player fits through the square entrance")
