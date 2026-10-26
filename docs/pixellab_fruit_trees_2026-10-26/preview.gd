extends Node2D

const IDS: Array[String] = ["apple","peach","pear","cherry"]
const FOLDER: String = "res://docs/pixellab_fruit_trees_2026-10-26"

func _ready() -> void:
	get_tree().root.size = Vector2i(880, 660)
	get_tree().root.content_scale_size = Vector2i(880, 660)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background: ColorRect = ColorRect.new()
	background.color = Color("29323a")
	background.size = Vector2(880,660)
	add_child(background)
	_label("FRUIT TREES - PIXELLAB EDITS FROM EXISTING SPRITES", Vector2(20,12))
	_label("RIPE FRUIT", Vector2(20,48))
	_label("AFTER HARVEST", Vector2(20,358))
	var installing: bool = OS.get_cmdline_user_args().has("install")
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	add_child(bag)
	var rows: Array = []
	for index: int in range(IDS.size()):
		var id: String = IDS[index]
		var path: String = "res://trees/definitions/%s.tres" % id
		var definition: TreeDefinition = load(path) as TreeDefinition
		var mature: Texture2D = load("res://assets/Trees/Fruit64x80/%s_mature.png" % id) as Texture2D
		var ready: Texture2D = load("res://assets/Trees/Fruit64x80/%s_ready.png" % id) as Texture2D
		assert(mature != null and ready != null)
		assert(mature.get_size() == Vector2(64,80) and ready.get_size() == Vector2(64,80))
		if installing:
			definition.stage_textures[2] = mature
			definition.ready_texture = ready
			assert(ResourceSaver.save(definition,path) == OK)
		assert(definition.is_valid())
		assert(definition.stage_textures[2] == mature and definition.ready_texture == ready)
		var tree: FruitTree = FruitTree.new()
		tree.definition = definition
		tree.initialize(1000.0)
		tree.position = Vector2(110+index*220,310)
		tree.scale = Vector2(3,3)
		add_child(tree)
		assert(tree.water(1000.0))
		tree.refresh(1000.0+definition.growth_seconds)
		assert(tree.is_mature() and not tree.has_fruit())
		assert(tree.sprite.texture == mature)
		tree.refresh(1000.0+definition.growth_seconds+definition.fruit_cycle_seconds)
		assert(tree.has_fruit() and tree.sprite.texture == ready)
		var collider: Transform2D = tree.trunk.transform
		var used: Rect2i = ready.get_image().get_used_rect()
		assert(is_equal_approx(tree.sprite.position.y + float(used.end.y) - ready.get_height()*0.5,0.0))
		var harvested: FruitTree = FruitTree.new()
		harvested.definition = definition
		harvested.initialize(1000.0)
		harvested.position = Vector2(110+index*220,610)
		harvested.scale = Vector2(3,3)
		add_child(harvested)
		harvested.water(1000.0)
		harvested.refresh(1000.0+definition.growth_seconds+definition.fruit_cycle_seconds)
		assert(harvested.harvest(bag))
		assert(not harvested.has_fruit() and harvested.is_mature())
		assert(harvested.sprite.texture == mature)
		assert(harvested.trunk.transform == collider)
		assert(bag.count_item(definition.harvest_item.item_id) == definition.harvest_amount)
		used = mature.get_image().get_used_rect()
		assert(is_equal_approx(harvested.sprite.position.y + float(used.end.y) - mature.get_height()*0.5,0.0))
		_label(id.capitalize(),Vector2(70+index*220,320))
		_label(id.capitalize(),Vector2(70+index*220,620))
		rows.append({"species":id,"ready":true,"after_harvest":true,"root_aligned":true,"collider_preserved":true,"yield":definition.harvest_amount})
	for frame: int in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(FOLDER+"/game_preview.png") == OK)
	var report: Dictionary = {"ok":true,"native_size":[64,80],"species":rows}
	var file: FileAccess = FileAccess.open(FOLDER+"/verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("FRUIT_SPRITES_VERIFIED " + JSON.stringify(report))
	get_tree().quit(0)

func _label(text: String, at: Vector2) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("f1e9d3"))
	add_child(label)
