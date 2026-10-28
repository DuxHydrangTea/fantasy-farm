extends Node
var world: FarmWorld

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	_run.call_deferred()

func _frames() -> void:
	for index: int in range(6):
		await get_tree().process_frame

func _capture(title: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://debug_saves/shop_split/flower_" + title + ".png") == OK)

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await _frames()
	var catalog: SaveCatalog = SaveCatalog.new()
	var repo: LocalSaveRepository = LocalSaveRepository.new("user://saves", catalog)
	var saved: Dictionary = repo.read_profile("local")
	assert(saved.ok and saved.get("found", false))
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var restored: Dictionary = adapter.restore(saved.snapshot, float(saved.snapshot.saved_at))
	assert(restored.ok, str(restored.get("error")))
	world.tool_upgrades.profile_ready = true
	world.player.global_position = Vector2(1990, 530)
	world.player.camera.position = Vector2(0, -80)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.zoom = Vector2(2, 2)
	world.player.camera.force_update_scroll()
	world.weather.effects._activate(WeatherManager.Weather.SUNNY)
	world.weather.day_night.refresh(12 * 3600 - WeatherSchedule.UTC_OFFSET, Color.WHITE)
	for node: Node in world.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).hide()
	await _capture("shop-street")
	for npc_name: String in ["LaiBuon", "FlowerMerchant", "PetMerchant", "BlacksmithMerchant"]:
		var npc: ShopMerchant = world.get_node(npc_name) as ShopMerchant
		world.player.global_position = npc.interaction_position() + Vector2(0, 24)
		assert(npc.open_shop(world.player))
		await _capture(npc_name)
		var layout: Dictionary = {"shop":npc_name, "root":str(npc.shop_ui.root.size), "panel":str(npc.shop_ui.panel.get_global_rect()), "tabs":[]}
		for id: int in npc.shop_ui._category_tabs:
			var tab: Button = npc.shop_ui._category_tabs[id]
			layout.tabs.append({"id":id, "visible":tab.visible, "size":str(tab.size), "rect":str(tab.get_global_rect())})
		print(JSON.stringify(layout))
		if npc_name == "BlacksmithMerchant":
			npc.shop_ui.show_category(ShopUI.UPGRADES)
			await _capture("blacksmith-upgrades")
		npc.shop_ui.close(false)
	print("SHOP_SPLIT_PREVIEW_OK: real save loaded without writing; 5 screenshots captured")
	world.free()
	get_tree().quit()
