extends Node2D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().root.size = Vector2i(1000, 600)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.18, 0.24, 0.19)
	background.size = Vector2(1000, 600)
	add_child(background)
	var layer: Node2D = Node2D.new()
	layer.scale = Vector2(4, 4)
	layer.position = Vector2(220, 440)
	add_child(layer)
	var merchant: ShopMerchant = load("res://scenes/characters/flower_merchant.tscn").instantiate() as ShopMerchant
	layer.add_child(merchant)
	for language: String in ["vi", "en"]:
		Language.set_language(language)
		merchant.thank_customer()
		for i: int in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://debug_saves/bubble_flip/" + language + ".png")
		assert(merchant.bubble_text.get_theme_font_size("font_size") == 12)
		assert(merchant.bubble.get_global_rect().grow(0.1).encloses(merchant.bubble_text.get_global_rect()))
	print("BUBBLE_FLIP_PREVIEW_OK")
	merchant.free()
	get_tree().quit()
