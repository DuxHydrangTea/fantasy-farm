extends Control
var failures: Array[String] = []

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(800, 420)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = preload("res://resources/ui/game_theme.tres")
	var background: ColorRect = ColorRect.new()
	background.color = Color("29323a")
	background.size = Vector2(800,420)
	add_child(background)
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	add_child(bag)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(40,45)
	grid.add_theme_constant_override("h_separation",20)
	grid.add_theme_constant_override("v_separation",30)
	add_child(grid)
	var asset_count: int = 0
	for file: String in ResourceLoader.list_directory("res://assets/Icons/seeds/flowers16"):
		if file.ends_with("_seed.png"):
			var texture: Texture2D = load("res://assets/Icons/seeds/flowers16/" + file) as Texture2D
			if texture == null or texture.get_size() != Vector2(16,16):
				failures.append("Invalid asset: " + file)
			asset_count += 1
	if asset_count != 32:
		failures.append("Expected 32 individual icons")
	var paths: Dictionary = {}
	for i: int in range(10):
		var item: ItemDefinition = load("res://items/seeds/flower_%02d_seed.tres" % (i+1)) as ItemDefinition
		if item == null or item.icon == null or item.icon.get_size() != Vector2(16,16):
			failures.append("Missing or wrong-size icon %d" % i)
			continue
		paths[item.icon.resource_path] = true
		bag.add(item, 24)
		var box: VBoxContainer = VBoxContainer.new()
		box.custom_minimum_size.x = 124
		grid.add_child(box)
		var title: Label = Label.new()
		title.text = (item.crop as FlowerDefinition).display_name
		title.add_theme_font_size_override("font_size",16)
		box.add_child(title)
		var slot: InventorySlot = InventorySlot.new()
		slot.inventory = bag
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(64,68)
		box.add_child(slot)
		if slot._icon.texture != item.icon:
			failures.append("Inventory icon mismatch %d" % i)
	if paths.size() != 10:
		failures.append("Icons are not unique")
	_capture.call_deferred()

func _capture() -> void:
	for i: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/flower_seed_icons_16x16_2026-10-26/inventory-preview.png")
	var report: FileAccess = FileAccess.open("res://docs/flower_seed_icons_16x16_2026-10-26/verification.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"resources_loaded":10,"inventory_slots":10,"failures":failures},"  "))
	get_tree().quit(0 if failures.is_empty() else 1)
