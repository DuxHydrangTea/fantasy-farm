extends Node2D
## Save-isolated orchard preview; timestamps are frozen after creating the farm.
var world: FarmWorld
var tree: FruitTree
var menu: GraftMenu
@export var review_quality: bool = false

func _ready() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(12500)
	var now: float = world.farming.time_manager.now()
	world.farming.time_manager.clock_source = func() -> float: return now
	world.trees.reset()
	var definition: TreeDefinition = world.trees.definitions[&"apple"]
	var start: float = now - definition.growth_seconds - definition.fruit_cycle_seconds
	tree = world.trees.create_tree(Vector2i(12,61), definition, start) as FruitTree
	tree.growth_started_at = start
	tree.matures_at = start + definition.growth_seconds
	tree.refresh(now)
	world.player.selection.inventory.add(preload("res://items/boosters/grafting_wax.tres"),2)
	world.player.global_position = tree.global_position + Vector2(0,24)
	menu = world.graft_menu
	menu.open_tree(tree)
	menu._select_direction(FruitTree.Graft.QUALITY if review_quality else FruitTree.Graft.YIELD)

func _exit_tree() -> void:
	TimeManager.clock_source = Time.get_unix_time_from_system
