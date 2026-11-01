extends Node
## Isolated UI review fixture. MainWorld is a child: never binds player saves.
var world: FarmWorld
var prefix: String

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	prefix = "before" if OS.get_cmdline_user_args().has("before") else "after"
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(16, 8)
	world.player.wallet.set_balance(907959824)
	world.weather.set_debug_hour(12)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(43, 13)))
	world.player.camera.zoom = Vector2(1.25, 1.25)
	world.player.camera.reset_smoothing()
	await get_tree().create_timer(0.4).timeout
	if OS.get_cmdline_user_args().has("concept_background"):
		world.player.camera.zoom = Vector2(0.85, 0.85)
		world.player.camera.reset_smoothing()
		for node: Node in world.find_children("*", "CanvasLayer", true, false):
			(node as CanvasLayer).hide()
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg("res://docs/ui_concept_background.jpg", 0.88)
		var icons: Dictionary = {}
		var items: Dictionary = {
			"hoe": preload("res://items/tools/hoe.tres"),
			"water": preload("res://items/tools/watering_can.tres"),
			"seed": preload("res://items/seeds/carrot_seed.tres"),
			"carrot": preload("res://items/harvest_produces/carrot_produces.tres"),
			"medicine": preload("res://items/boosters/animal_medicine.tres"),
			"fertilizer": preload("res://items/boosters/crop_fertilizer.tres")}
		for id: String in items:
			icons[id] = Marshalls.raw_to_base64((items[id] as ItemDefinition).icon.get_image().save_png_to_buffer())
		var icon_file: FileAccess = FileAccess.open("res://docs/ui_concept_icons.json", FileAccess.WRITE)
		icon_file.store_string(JSON.stringify(icons))
		assert(SaveManager.adapter == null)
		get_tree().quit()
		return
	for child: Node in world.get_children():
		if child is WorldPersistence:
			(child as WorldPersistence)._build_notice()
			(child as WorldPersistence)._notice(tr("Progress saved"), true)
	if OS.get_cmdline_user_args().has("separate_quality"):
		var bag: InventoryComponent = world.player.selection.inventory
		for item: ItemDefinition in [preload("res://items/harvest_produces/carrot_produces.tres"), preload("res://items/harvest_produces/wheat_produces.tres")]:
			for tier: int in range(3):
				bag.add(item, 20 + tier * 10, tier)
		var ui: InventoryUI = world.player.get_node("InventoryUI") as InventoryUI
		ui.open()
		for index: int in range(bag.slot_count):
			if bag.slot(index).tiers[1] > 0:
				ui._inspect_slot(index)
				break
		await _capture("separate_quality")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("all_shop_icons"):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		for shop_name: String in ["LaiBuon", "FlowerMerchant", "PetMerchant", "BlacksmithMerchant"]:
			var merchant: ShopMerchant = world.get_node(shop_name) as ShopMerchant
			world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
			merchant.open_shop(world.player)
			for category: int in merchant.catalog.category_ids:
				merchant.shop_ui.show_category(category)
				await _capture("icons_" + shop_name + "_" + str(category))
			merchant.menu.close(false)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("sales_icons"):
		var buyer: ShopMerchant = preload("res://scenes/characters/produce_buyer.tscn").instantiate() as ShopMerchant
		world.add_child(buyer)
		buyer.global_position = world.player.global_position + Vector2(24, 0)
		world.player.selection.inventory.add(preload("res://items/harvest_produces/carrot_produces.tres"), 120)
		buyer.open_shop(world.player)
		await _capture("sales_icons")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("speech"):
		var speaker: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
		if OS.get_cmdline_user_args().has("zoom_speech"):
			world.player.camera.zoom = Vector2(2.5, 2.5)
		world.player.global_position = speaker.global_position + Vector2(0, 50)
		world.player.camera.reset_smoothing()
		Language.set_language("vi")
		speaker.thank_customer()
		await _capture("speech_vi")
		Language.set_language("en")
		speaker.thank_customer()
		await _capture("speech_en")
		get_tree().quit()
		return
	for language: String in ["vi", "en"]:
		Language.set_language(language)
		for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(size)
			await _capture("hud_" + language + "_" + str(size.x))
	if prefix == "after":
		Language.set_language("vi")
		world.objectives.progress.state_query = func(_condition: StringName) -> int: return 1
		world.objectives.progress.refresh_state()
		await _capture("objective_ready")
		world.player.get_node("FarmSettings").call("show_settings")
		await _capture("settings")
		(world.player.get_node("FarmSettings") as TradeMenu).close(false)
		world.player.selection.set_inventory_open(true)
		await _capture("inventory")
		world.player.selection.set_inventory_open(false)
		var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
		world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
		merchant.open_shop(world.player)
		await _capture("shop")
		merchant.menu.close(false)
		world.workers.hire("crop")
		var actor: WorkerActor = world.workers.actor_for(world.workers.records[0].id)
		for child: Node in actor.get_children():
			if child is WorkerBoard:
				world.player.global_position = (child as WorkerBoard).interaction_position()
				(child as WorkerBoard).open_shop(world.player)
		await _capture("worker")
	assert(SaveManager.adapter == null, "Preview must never bind a profile")
	get_tree().quit()

func _capture(label: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/ui_" + prefix + "_" + label + ".png")
