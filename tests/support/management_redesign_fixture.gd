class_name ManagementRedesignFixture
extends Node2D
## Seeded, save-isolated world for visual and interaction QA.
var world: FarmWorld
var actors: Array[AnimalActor] = []
@export var show_tree: bool = false

func _ready() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.pen_upgrades.profile_ready = true
	world.tree_plot_upgrades.profile_ready = true
	world.player.wallet.set_balance(1000000)
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		if world.is_ancestor_of(node):
			node.free()
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	var quote: Dictionary = world.pen_upgrades.quote(pen)
	world.pen_upgrades.purchase(pen, int(quote.level), int(quote.price))
	for index: int in range(4):
		var actor: AnimalActor = preload("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
		actor.definition = preload("res://animals/definitions/chicken.tres")
		actor.pen = pen
		actor.persistent_id = StringName("ui_chicken_%02d" % index)
		actor.initial_age_seconds = 0 if index == 2 else actor.definition.maturity_seconds
		actor.position = pen.bounds.get_center() + Vector2(index * 12, 0)
		pen.add_child(actor)
		actor.needs.restore_state([95, 80, 90, 40][index], [85, 60, 75, 25][index], world.farming.time_manager.now())
		actors.append(actor)
	world.trees.reset()
	for level: int in range(1, 3):
		var offered: Dictionary = world.tree_plot_upgrades.quote(TreeDefinition.Kind.FRUIT)
		world.tree_plot_upgrades.purchase(TreeDefinition.Kind.FRUIT, int(offered.level), int(offered.price))
	var origin: Vector2i = TreePlantation.region_for(TreeDefinition.Kind.FRUIT).position + Vector2i(2, 3)
	for column: int in range(3):
		for row: int in range(6):
			world.trees.create_tree(origin + Vector2i(column * 3, row * 3), world.trees.definitions[&"apple"], world.farming.time_manager.now() - 50000)
	world.player.wallet.set_balance(100000)
	var pen_board: PenBoard = pen.get_node("ManagementSign") as PenBoard
	pen_board.menu.name = "PenMenu"
	var tree_board: TreePlotBoard = world.get_node("FruitPlotBoard") as TreePlotBoard
	tree_board.menu.name = "TreeMenu"
	if show_tree:
		open_tree()
	else:
		open_pen()

func open_pen() -> PenDashboard:
	var board: PenBoard = world.get_node("CoopPen/ManagementSign") as PenBoard
	world.player.global_position = board.global_position + Vector2(0, 24)
	board.open_board(world.player)
	return board.menu

func open_tree() -> TreePlotMenu:
	var board: TreePlotBoard = world.get_node("FruitPlotBoard") as TreePlotBoard
	world.player.global_position = board.global_position + Vector2(0, 24)
	board.open_board(world.player)
	return board.menu
