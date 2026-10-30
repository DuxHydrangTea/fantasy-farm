extends Node2D
## Isolated QA world. Does not bind a personal save/profile.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var crops: Array[Crop] = []
var animal: AnimalActor
var worker_menu: WorkerMenu

func _ready() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.weather.set_debug_hour(12)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.land.state.restore_columns(12, 4)
	var now: float = world.farming.time_manager.now()
	var soil: Array[Dictionary] = []
	for x: int in range(4):
		soil.append({"cell": [50 + x * 2, 22], "state": 1})
	world.farming.restore_soil(soil)
	for x: int in range(4):
		var cell: Vector2i = Vector2i(50 + x * 2, 22)
		world.farming.restore_crop(cell, preload("res://crops/field/wheat/wheat.tres"), now - 600, now + 600, 0.5, now)
		var crop: Crop = world.farming.get_crop(cell)
		crop.conditions.pests = x == 1 or x == 3
		crop.conditions.weeds = x == 2 or x == 3
		crop._update_condition_visuals()
		crops.append(crop)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(56, 21)))
	world.player.animation.face(Vector2.DOWN)
	world.player.camera.reset_smoothing()
	world.player.selection.inventory.add(preload("res://items/boosters/pesticide.tres"), 5)
	world.player.selection.inventory.add(preload("res://items/boosters/animal_medicine.tres"), 5)
	animal = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	animal.initial_age_seconds = 10000.0
	world.get_node("CoopPen").add_child(animal)
	animal.process_mode = Node.PROCESS_MODE_DISABLED
	animal.global_position = world.player.global_position + Vector2(50, 20)
	animal.needs.restore_state(0, 0, now)
	animal.health.sick = true
	animal._refresh_health_badges()

func open_crop_workers() -> bool:
	world.player.wallet.set_balance(1000000)
	world.workers.hire("crop")
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		var merchant: ShopMerchant = node as ShopMerchant
		if merchant != null and merchant.menu is WorkerMenu and (merchant.menu as WorkerMenu).role == "crop":
			worker_menu = merchant.menu as WorkerMenu
			return worker_menu.open(merchant, world.player)
	return false
