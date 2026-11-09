extends Node
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Language.set_language("vi")
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(2000000)
	var merchant: ShopMerchant = world.get_node("PetMerchant") as ShopMerchant
	var shop: ShopUI = merchant.shop_ui
	shop.open(merchant, world.player)
	shop.show_category(ShopOffer.Category.ANIMAL)
	var premium: AnimalShopOffer
	for offer: AnimalShopOffer in merchant.catalog.animal_offers:
		if offer.animal.animal_id == &"chicken_18": premium = offer
	assert(premium != null)
	shop.select_animal_offer(premium)
	var output: String = "C:/projects/fantasy-farm/.godot/chicken-shop-preview"
	DirAccess.make_dir_recursive_absolute(output)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		get_tree().root.size = size
		get_tree().root.content_scale_size = size
		for frame: int in range(8): await get_tree().process_frame
		shop.browse.ensure_control_visible(shop._buttons[premium])
		for frame: int in range(5): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("chicken-shop-%dx%d.png" % [size.x, size.y]))
		assert(Rect2(Vector2.ZERO, Vector2(size)).grow(1).encloses(shop.panel.get_global_rect()))
	assert(shop.production_row.value.text.contains("525"))
	assert(SaveManager.adapter == null)
	print("CHICKEN_SHOP_PREVIEW ", shop.details.text)
	shop.close(false)
	get_tree().quit()
