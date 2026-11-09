extends Node
## Save-isolated visual read-back for reward bursts and animal care icons.
var world: FarmWorld
var animals: Array[AnimalActor] = []
const CareBubble = preload("res://components/animals/animal_care_bubble.gd")
const OUTPUT: String = "res://.godot/care-feedback-preview"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Language.set_language("vi")
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	world.weather.day_night.refresh(12 * 3600 - WeatherSchedule.UTC_OFFSET, Color.WHITE)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.zoom = Vector2(3, 3)
	var base: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(55, 22)))
	world.player.global_position = base + Vector2(0, 40)
	world.player.camera.reset_smoothing()
	var species: Array[String] = ["chicken", "cow", "sheep"]
	for index: int in range(3):
		var animal: AnimalActor = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
		animal.definition = load("res://animals/definitions/" + species[index] + ".tres") as AnimalDefinition
		animal.pen = world.get_node("CoopPen") as AnimalPen
		animal.initial_age_seconds = animal.definition.maturity_seconds
		world.add_child(animal)
		animal.global_position = base + Vector2((index - 1) * 90, 0)
		animals.append(animal)
	animals[0]._on_serving_consumed(AnimalTrough.Kind.FOOD, preload("res://items/feeds/poultry_feed.tres"))
	animals[1]._on_serving_consumed(AnimalTrough.Kind.WATER, null)
	CareBubble.present(animals[2], preload("res://items/boosters/animal_medicine.tres").icon)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		get_tree().root.size = size
		get_tree().root.content_scale_size = size
		world.player.camera.zoom = Vector2.ONE * (3.0 if size.x > 1000 else 2.0)
		world.player.camera.reset_smoothing()
		world.player.item_feedback.clear()
		world.player.item_feedback.present_animal_collection(animals[1], 7)
		for burst: HarvestBurst in world.player.item_feedback._bursts:
			burst._process(0.14)
		for popup: ItemGainPopup in world.player.item_feedback._popups:
			popup.start_after(0.0)
			popup._process(0.2)
		for frame: int in range(8):
			await get_tree().process_frame
		for animal: AnimalActor in animals:
			var bubble: Node2D = animal.get_node("CareBubble") as Node2D
			var panel: PanelContainer = bubble.get_node("BubbleVisual/BubblePanel") as PanelContainer
			var row: HBoxContainer = panel.get_node("Row") as HBoxContainer
			assert((row.get_node("Icon") as TextureRect).texture != null)
			assert(Rect2(Vector2.ZERO, panel.size).encloses(row.get_rect()))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUTPUT.path_join("care-%dx%d.png" % [size.x, size.y]))
	assert(SaveManager.adapter == null)
	print("CARE_FEEDBACK_PREVIEW_OK")
	get_tree().quit()
