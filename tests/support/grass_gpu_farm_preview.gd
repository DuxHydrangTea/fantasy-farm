extends Node2D
## F6 preview: a fresh child World and QA herd; never binds personal persistence.
var world: FarmWorld

func _ready() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	_focus.call_deferred()

func _focus() -> void:
	world.player.global_position = Vector2(1298, 826)
	world.player.camera.zoom = Vector2(2, 2)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.reset_smoothing()
	world.player.camera.make_current()
	world.player.camera.force_update_scroll()
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	var pen: AnimalPen = world.get_node("BarnPen")
	for species: String in {"cow": 12, "sheep": 8, "pig": 8, "horse": 8}:
		var count: int = 12 if species == "cow" else 8
		for i: int in range(count):
			var actor: AnimalActor = load("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
			actor.definition = load("res://animals/definitions/" + species + ".tres")
			actor.initial_age_seconds = actor.definition.maturity_seconds + 10.0
			actor.position = Vector2(32 + i % 8 * 40, 40 + floori(float(i) / 8.0) * 40)
			pen.add_child(actor)
