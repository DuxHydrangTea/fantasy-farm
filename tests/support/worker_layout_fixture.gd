extends Node2D
## Isolated farm child for all three worker role previews; no personal save binding.
var world: FarmWorld
var menu: WorkerMenu
@export_enum("crop", "orchard", "ranch") var role: String = "crop"
@export var employed: bool = true
@export var show_confirmation: bool = false

func _ready() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(12500)
	var timestamp: float = world.farming.time_manager.now()
	world.farming.time_manager.clock_source = func() -> float: return timestamp
	world.trees.reset()
	for index: int in range(10):
		world.trees.create_tree(Vector2i(12 + index * 3, 61), world.trees.definitions[&"apple"], timestamp)
	var source: InventoryComponent = world.storages.inventory("farm_supply_storage")
	source.add(preload("res://items/seeds/carrot_seed.tres"), 120)
	source.add(preload("res://items/boosters/crop_fertilizer.tres"), 24)
	source.add(preload("res://items/feeds/poultry_feed.tres"), 80)
	var pen: AnimalPen = world.workers.bridge.pens()[0]
	if employed:
		world.workers.hire(role, String(pen.persistent_id) if role == "ranch" else "")
		if role == "crop":
			world.workers.configure_crop(true, true, false)
	var board: WorkerBoard = world.get_node({"crop":"CropWorkers", "orchard":"OrchardWorkers", "ranch":"RanchWorkers"}[role]) as WorkerBoard
	world.player.global_position = board.interaction_position() + Vector2(0, 24)
	menu = board.menu as WorkerMenu
	board.open_shop(world.player)
	if show_confirmation:
		menu._dismiss()

func _exit_tree() -> void:
	TimeManager.clock_source = Time.get_unix_time_from_system
