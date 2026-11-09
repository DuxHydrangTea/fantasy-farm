extends Node
## Save-isolated rendered QA for icon values in wide and compact layouts.
var world: FarmWorld
var output: String = "C:/projects/fantasy-farm/.godot/visual-values-preview"

func _ready() -> void:
	_run.call_deferred()

func _shot(label: String, panel: Control) -> void:
	for frame: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var size: Vector2i = get_tree().root.size
	get_viewport().get_texture().get_image().save_png(output.path_join("%s-%dx%d.png" % [label, size.x, size.y]))
	assert(Rect2(Vector2.ZERO, Vector2(size)).grow(1).encloses(panel.get_global_rect()), label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	Language.set_language("vi")
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(2000000)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		get_tree().root.size = size
		get_tree().root.content_scale_size = size
		var merchant: ShopMerchant = world.get_node("PetMerchant") as ShopMerchant
		merchant.shop_ui.open(merchant, world.player)
		merchant.shop_ui.show_category(ShopOffer.Category.ANIMAL)
		await _shot("livestock", merchant.shop_ui.panel)
		merchant.shop_ui.close(false)
		for frame: int in range(24):
			await get_tree().process_frame
		var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
		var actor: AnimalActor = load("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
		actor.definition = load("res://animals/definitions/chicken_18.tres") as AnimalDefinition
		actor.pen = pen
		actor.persistent_id = &"visual_preview_chicken"
		actor.initial_age_seconds = actor.definition.maturity_seconds
		pen.add_child(actor)
		var board: PenBoard = pen.get_node("ManagementSign") as PenBoard
		world.player.global_position = board.global_position + Vector2(0, 24)
		board.open_board(world.player)
		await _shot("pen", board.menu.panel)
		board.menu.close(false)
		var inspector: AnimalInfoPanel = load("res://scenes/ui/animal_info.tscn").instantiate() as AnimalInfoPanel
		add_child(inspector)
		inspector.inspect(actor)
		assert(inspector.production_row.icon.texture == actor.definition.production.production_item.icon)
		await _shot("animal-info", inspector.title.get_parent().get_parent() as Control)
		inspector.free()
		actor.free()
		for frame: int in range(24):
			await get_tree().process_frame
		world.land.state.restore_blocks(24)
		world.orders.service.fill_empty()
		var serial: int = int(world.orders.service.capture().slots[0].serial)
		var entry: OrderDefinition = world.orders.service.definition(serial)
		for index: int in range(entry.items.size()):
			world.orders.service.inventory.add(entry.items[index], entry.amounts[index], 1)
		world.player.global_position = world.orders.global_position + Vector2(0, 24)
		world.orders.open_board(world.player)
		world.orders.menu._request("perfect")
		await _shot("order-confirmation", world.orders.menu.panel)
		world.orders.menu.close(false)
		for frame: int in range(24):
			await get_tree().process_frame
	assert(SaveManager.adapter == null)
	print("VISUAL_VALUES_PREVIEW_OK")
	get_tree().quit()
