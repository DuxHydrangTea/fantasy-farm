extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld

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
