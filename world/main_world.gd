class_name FarmWorld
extends Node2D
## MainWorld composition root. References are serialized in the scene.
@export var player: FarmPlayer
@export var farming: FarmingController
var land: LandExpansionComponent
var apiary: ApiarySystem
var weather: WeatherManager
var trees: TreePlantation
var objectives: ObjectiveTracker
var objective_ui: ObjectiveUI
var orders: OrderBoard
var tutorial: TutorialProgress = TutorialProgress.new()
var help_ui: HelpUI
var tutorial_hints: TutorialHints
var pen_boards: Array[PenBoard] = []
var starter_content: StarterContent
var grass: FarmGrassField
@export var gpu_grass_enabled: bool = true
@export var order_board_position: Vector2 = Vector2(1664, 248)
## Authored window/gate anchors in world-local pixels, independent of sprite names.
@export var night_light_positions: Array[Vector2] = [Vector2(1350, 308), Vector2(1183, 622), Vector2(1740, 172), Vector2(1666, 622), Vector2(1010, 274), Vector2(1384, 274), Vector2(1480, 274)]

func _enter_tree() -> void:
	assert(player != null and farming != null, "Assign MainWorld player and farming references")
	player.farming_actions.farming = farming

	if is_instance_valid(land):
		return
	starter_content = StarterContent.new(self)
	starter_content.prepare()
	weather = WeatherManager.new()
	weather.world = self
	weather.name = "WeatherManager"
	farming.weather = weather.schedule
	_wire_weather(self)
	# Typed composition keeps land wiring independent of node names.
	land = LandExpansionComponent.new()
	land.name = "LandExpansion"
	land.farming = farming
	land.player = player
	farming.land = land.state
	add_child(land)
	apiary = ApiarySystem.new()
	apiary.name = "Apiary"
	apiary.world = self
	apiary.farming = farming
	farming.apiary = apiary
	add_child(apiary)
	add_child(weather)
	trees = TreePlantation.new()
	trees.name = "TreePlantation"
	trees.world = self
	add_child(trees)
	objectives = ObjectiveTracker.new()
	objectives.name = "Objectives"
	objectives.world = self
	add_child(objectives)

func _ready() -> void:
	starter_content.setup()
	objectives.setup()
	objective_ui = ObjectiveUI.new()
	objective_ui.name = "ObjectiveUI"
	objective_ui.model = objectives.progress
	objective_ui.selection = player.selection
	add_child(objective_ui)
	orders = OrderBoard.new()
	orders.name = "OrderBoard"
	orders.world = self
	orders.position = order_board_position
	add_child(orders)
	help_ui = HelpUI.new()
	help_ui.name = "HelpUI"
	help_ui.world = self
	add_child(help_ui)
	objective_ui.help_requested.connect(help_ui.open_help)
	tutorial_hints = TutorialHints.new()
	tutorial_hints.name = "TutorialHints"
	tutorial_hints.world = self
	add_child(tutorial_hints)
	for child: Node in get_children():
		if child is AnimalPen:
			for node: Node in child.get_children():
				if node is PenBoard:
					pen_boards.append(node as PenBoard)
	grass = FarmGrassField.new()
	grass.name = "GPUGrass"
	grass.world = self
	add_child(grass)

func _wire_weather(node: Node) -> void:
	if node is AnimalPen:
		(node as AnimalPen).weather = weather.schedule
	for child: Node in node.get_children():
		_wire_weather(child)
