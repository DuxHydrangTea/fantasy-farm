extends SceneTree

const IDS: Array[String] = [
	"autumn_maple", "blue_conifer", "brown_palm", "evergreen_spruce",
	"flowering_cactus", "golden_aspen", "golden_birch", "magic_blue",
	"orange_oak", "palm", "pink_blossom", "purple_blossom", "red_maple", "willow"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var install: bool = OS.get_cmdline_user_args().has("install")
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	root.add_child(bag)
	for tree_id: String in IDS:
		var item_path: String = "res://items/trees/%s_sapling.tres" % tree_id
		var icon_path: String = "res://assets/Icons/tree_saplings/%s_sapling.png" % tree_id
		var item: ItemDefinition = load(item_path) as ItemDefinition
		var icon: Texture2D = load(icon_path) as Texture2D
		assert(item != null and icon != null, tree_id)
		assert(icon.get_size() == Vector2(32, 32), tree_id)
		assert(item.item_id == StringName(tree_id + "_sapling"), tree_id)
		if install:
			item.icon = icon
			assert(ResourceSaver.save(item, item_path) == OK, tree_id)
		else:
			assert(item.icon.resource_path == icon_path, tree_id)
		assert(bag.add(item, 1) == 1, tree_id)
	if install:
		print("Installed and validated 14 sapling icon resources.")
		quit(0)
		return
	root.size = Vector2i(1120, 440)
	root.content_scale_size = Vector2i(1120, 440)
	var board: Control = Control.new()
	board.theme = load("res://resources/ui/game_theme.tres") as Theme
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.size = Vector2(1120, 440)
	root.add_child(board)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.12, 0.15, 0.17)
	background.size = board.size
	board.add_child(background)
	var title: Label = Label.new()
	title.text = "TIMBER SAPLINGS - 14 NEW INVENTORY ICONS"
	title.position = Vector2(28, 18)
	board.add_child(title)
	for index: int in range(IDS.size()):
		var column: int = index % 7
		var row: int = int(index / 7.0)
		var origin: Vector2 = Vector2(20 + column * 156, 84 + row * 160)
		var slot: InventorySlot = InventorySlot.new()
		slot.inventory = bag
		slot.slot_index = index
		slot.position = origin + Vector2(36, 0)
		slot.size = Vector2(64, 68)
		board.add_child(slot)
		var label: Label = Label.new()
		label.text = IDS[index].replace("_", " ").capitalize()
		label.position = origin + Vector2(0, 82)
		label.size = Vector2(150, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		board.add_child(label)
		var displayed: TextureRect = slot.get_node("Icon") as TextureRect
		assert(displayed.texture == bag.get_slot_item(index).icon, IDS[index])
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	assert(not screenshot.is_empty())
	assert(screenshot.save_png("res://docs/meowa_saplings_2026-10-26/inventory_preview.png") == OK)
	print("Verified 14 item icons through InventoryComponent and InventorySlot; preview saved.")
	quit(0)
