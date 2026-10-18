extends SceneTree

const Fixture = preload("res://tests/support/farming_fixture.gd")
const Farming = preload("res://components/farming_controller.gd")
const Clock = preload("res://components/time_manager.gd")
const Bag = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
var timestamp: float = 1000.0

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var clock: Clock = Clock.new()
	clock.clock_source = func() -> float: return timestamp
	root.add_child(clock)
	clock.set_process(false)
	var field: Node2D = Fixture.create_field()
	field.y_sort_enabled = true
	field.position = Vector2(80, 60)
	field.scale = Vector2(4, 4)
	var farming: Farming = field.get_node("FarmingController")
	farming.time_manager = clock
	root.add_child(field)
	var bag: Bag = Bag.new()
	root.add_child(bag)
	for row: int in range(3):
		var crop_name: String = ["carrot", "corn", "wheat"][row]
		var seed_path: String = "res://items/seeds/%s_seed.tres" % crop_name
		var seed: Item = load(seed_path) as Item
		bag.add(seed, 4)
		for column: int in range(4):
			var cell: Vector2i = Vector2i(4 + column * 3, 4 + row * 3)
			Fixture.mark_cell(field, cell)
			farming.till(cell)
			farming.plant(cell, bag, 2)
			var crop: Node = farming.get_crop(cell)
			crop.refresh(crop.planted_at + crop.definition.growth_seconds * [0.0, 0.4, 0.75, 1.0][column])
	var heading: Label = Label.new()
	heading.text = "CÂY TRỒNG · 4 GIAI ĐOẠN"
	heading.theme = load("res://resources/ui/game_theme.tres") as Theme
	heading.position = Vector2(330, 70)
	root.add_child(heading)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://.godot/crops-preview.png")
	quit(result)
