class_name FarmWorld
extends Node2D
## MainWorld composition root. References are serialized in the scene.
@export var player: FarmPlayer
@export var farming: FarmingController
var land: LandExpansionComponent
var apiary: ApiarySystem
var weather: WeatherManager
var trees: TreePlantation
## Authored window/gate anchors in world-local pixels, independent of sprite names.
@export var night_light_positions: Array[Vector2] = [Vector2(1350, 308), Vector2(1183, 622), Vector2(1740, 172), Vector2(1666, 622), Vector2(1010, 274), Vector2(1384, 274), Vector2(1480, 274)]

func _enter_tree() -> void:
	assert(player != null and farming != null, "Assign MainWorld player and farming references")
	player.farming_actions.farming = farming

	if is_instance_valid(land):
		return
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

func _wire_weather(node: Node) -> void:
	if node is AnimalPen:
		(node as AnimalPen).weather = weather.schedule
	for child: Node in node.get_children():
		_wire_weather(child)
