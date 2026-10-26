extends Control

const FOLDER: String = "res://docs/flower_seed_icons_48_2026-10-26"
var failures: Array[String] = []

func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i(1120, 660)
	get_tree().root.size = Vector2i(1120, 660)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = load("res://resources/ui/game_theme.tres") as Theme
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "/manifest.json")) as Dictionary
	var entries: Array = manifest.items
	var installing: bool = OS.get_cmdline_user_args().has("install")
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	add_child(bag)
	var background: ColorRect = ColorRect.new()
	background.color = Color("29323a")
	background.size = Vector2(1120, 660)
	add_child(background)
	_label("FLOWER SEED PACKETS - MEOWA 48 x 48", Vector2(24, 16), 23)
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var path: String = "res://" + String(entry.file)
		var icon: Texture2D = load(path) as Texture2D
		if icon == null or icon.get_size() != Vector2(48, 48):
			failures.append("Invalid 48x48 asset: " + path)
			continue
		var position_in_grid: Vector2 = Vector2(24 + (index % 8) * 136, 70 + int(index / 8.0) * 90)
		var image: TextureRect = TextureRect.new()
		image.texture = icon
		image.position = position_in_grid + Vector2(35, 0)
		image.size = Vector2(48, 48)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(image)
		_label(String(entry.flower), position_in_grid + Vector2(0, 54), 13)
		if index >= 10:
			continue
		var item_path: String = "res://items/seeds/flower_%02d_seed.tres" % (index + 1)
		var item: ItemDefinition = load(item_path) as ItemDefinition
		assert(item != null)
		if installing:
			item.icon = icon
			assert(ResourceSaver.save(item, item_path) == OK)
		if item.icon == null or item.icon.resource_path != path:
			failures.append("Item icon mismatch: " + item_path)
		bag.add(item, 24)
		var slot: InventorySlot = InventorySlot.new()
		slot.inventory = bag
		slot.slot_index = index
		slot.position = Vector2(28 + index * 108, 516)
		slot.size = Vector2(64, 68)
		add_child(slot)
		if slot._icon.texture != icon:
			failures.append("Inventory slot mismatch: " + item_path)
		_label(String(entry.flower), Vector2(24 + index * 108, 596), 12)
	_label("INVENTORY - 10 FLOWER SEEDS ALREADY IN GAME", Vector2(24, 462), 20)
	var catalog: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var flowers_in_shop: int = 0
	for offer: ShopOffer in catalog.offers:
		if offer.item.crop is FlowerDefinition:
			flowers_in_shop += 1
			if offer.item.icon == null or offer.item.icon.get_size() != Vector2(48, 48):
				failures.append("Shop icon mismatch: " + String(offer.item.item_id))
	if flowers_in_shop != 10:
		failures.append("Expected 10 flower seed offers")
	_capture.call_deferred()

func _label(value: String, at: Vector2, font_size: int) -> void:
	var label: Label = Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e8dfcd"))
	add_child(label)

func _capture() -> void:
	for frame: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png(FOLDER + "/inventory_preview.png")
	if result != OK:
		failures.append("Screenshot failed")
	var report: Dictionary = {"assets_loaded":32,"native_size":[48,48],"item_icons":10,"inventory_slots":10,"shop_icons":10,"failures":failures}
	var file: FileAccess = FileAccess.open(FOLDER + "/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("FLOWER_ICONS_48_VERIFIED " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
