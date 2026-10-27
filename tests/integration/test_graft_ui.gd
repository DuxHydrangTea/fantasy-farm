extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var tree: FruitTree
var menu: GraftMenu
var viewport: SubViewport
var previous_clock: Callable
var previous_floor: float
var timestamp: float

func before_each() -> void:
	previous_clock = TimeManager.clock_source
	previous_floor = TimeManager._last_timestamp
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(world)
	world.tool_upgrades.profile_ready = true
	timestamp = TimeManager.now()
	var fixed: float = timestamp
	TimeManager.clock_source = func() -> float: return fixed
	world.trees.reset()
	var definition: TreeDefinition = world.trees.definitions[&"apple"]
	var start: float = timestamp - definition.growth_seconds - definition.fruit_cycle_seconds
	tree = world.trees.create_tree(Vector2i(12,61), definition, start) as FruitTree
	tree.growth_started_at = start
	tree.matures_at = start + definition.growth_seconds
	tree.refresh(timestamp)
	world.player.global_position = tree.global_position + Vector2(0,24)
	menu = world.graft_menu
	assert_true(menu.open_tree(tree))
	await wait_process_frames(3)

func after_each() -> void:
	TimeManager.clock_source = previous_clock
	TimeManager._last_timestamp = previous_floor
	Language.set_language("en")

func test_review_is_free_and_explicit_confirmation_preserves_current_crop() -> void:
	assert_eq(menu.scene_file_path,"res://scenes/ui/grafting.tscn")
	assert_true(menu.confirm_button.disabled)
	menu._select_direction(FruitTree.Graft.YIELD)
	assert_eq(tree.pending_graft,FruitTree.Graft.NONE)
	assert_eq(int(menu._offer.wax),0)
	assert_false(menu.confirm_button.disabled)
	assert_string_contains((menu.get_node("%FutureCrop") as Label).text,"600")
	menu._confirm_choice()
	assert_eq(tree.pending_graft,FruitTree.Graft.YIELD)
	assert_eq(tree.harvest_amount(),300)
	assert_eq(tree.active_graft,FruitTree.Graft.NONE)
	menu._confirm_choice()
	assert_eq(tree.graft_revision,1)
	menu._collect()
	assert_eq(tree.active_graft,FruitTree.Graft.YIELD)
	assert_eq(world.player.selection.inventory.count_item(&"apple"),300)
	assert_eq(tree.harvest_amount(),600)

func test_missing_wax_direction_is_reviewable_and_paid_change_uses_one_wax() -> void:
	menu._choose(FruitTree.Graft.YIELD)
	menu._select_direction(FruitTree.Graft.QUALITY)
	assert_false(menu.quality_button.disabled)
	assert_true(menu.confirm_button.disabled)
	assert_eq(int(menu._offer.wax),1)
	world.player.selection.inventory.add(preload("res://items/boosters/grafting_wax.tres"),2)
	assert_false(menu.confirm_button.disabled)
	menu._confirm_choice()
	assert_eq(world.player.selection.inventory.count_item(GraftService.WAX),1)
	assert_eq(tree.pending_graft,FruitTree.Graft.QUALITY)
	assert_eq(tree.harvest_item(),tree.definition.harvest_item)
	menu._confirm_choice()
	assert_eq(world.player.selection.inventory.count_item(GraftService.WAX),1)

func test_external_revision_change_disables_old_review_until_reselected() -> void:
	world.player.selection.inventory.add(preload("res://items/boosters/grafting_wax.tres"),1)
	menu._select_direction(FruitTree.Graft.YIELD)
	assert_eq(world.grafting.choose(tree,FruitTree.Graft.QUALITY,tree.graft_revision),"")
	assert_true(menu.confirm_button.disabled)
	menu._confirm_choice()
	assert_eq(tree.pending_graft,FruitTree.Graft.QUALITY)
	assert_eq(world.player.selection.inventory.count_item(GraftService.WAX),1)
	menu._select_direction(FruitTree.Graft.YIELD)
	assert_eq(int(menu._offer.wax),1)
	assert_false(menu.confirm_button.disabled)
	menu._confirm_choice()
	assert_eq(tree.pending_graft,FruitTree.Graft.YIELD)
	assert_eq(world.player.selection.inventory.count_item(GraftService.WAX),0)

func test_full_bag_keeps_entire_ripe_crop_and_distance_closes_modal() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var seed: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
	bag.add(seed,bag.capacity_for(seed))
	assert_true(menu.harvest_button.disabled)
	menu._collect()
	assert_true(tree.has_fruit())
	assert_eq(bag.count_item(&"apple"),0)
	world.player.global_position += Vector2(200,0)
	menu._process(0.6)
	assert_false(menu.is_open)
	assert_false(world.player.selection.shop_open)

func test_compact_review_actions_fit_and_language_switch_keeps_plan() -> void:
	menu._select_direction(FruitTree.Graft.YIELD)
	var revision: int = menu._review_revision
	Language.set_language("vi")
	assert_eq(menu._review_revision,revision)
	assert_false(menu.confirm_button.disabled)
	viewport.set_meta(&"touch_ui_override",true)
	viewport.size = Vector2i(667,375)
	await wait_process_frames(8)
	assert_false((menu.get_node("%ReviewPanel") as PanelContainer).visible)
	for control: Control in [menu.panel,menu.close_button,menu.harvest_button,menu.confirm_button]:
		assert_true(Rect2(Vector2.ZERO,menu.root.size).grow(1).encloses(control.get_global_rect()))
	assert_gte(menu.confirm_button.size.y,48.0)
	viewport.set_meta(&"touch_ui_override",false)
	viewport.size = Vector2i(1280,720)
	await wait_process_frames(8)
	assert_eq(menu.confirm_button.get_parent(),menu.get_node("%ReviewBody"))
	assert_eq(menu.get_node("%ReviewContent").get_parent(),menu.get_node("%ReviewScroll"))
