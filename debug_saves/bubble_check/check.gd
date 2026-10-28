extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	for language: String in ["vi", "en"]:
		Language.set_language(language)
		for npc: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
			if not world.is_ancestor_of(npc):
				continue
			var merchant: ShopMerchant = npc as ShopMerchant
			merchant.thank_customer()
			await get_tree().process_frame
			await get_tree().process_frame
			assert(merchant.bubble_text.get_theme_font_size("font_size") == 12)
			assert(merchant.bubble.get_global_rect().grow(0.1).encloses(merchant.bubble_text.get_global_rect()), "Text must stay inside the bubble")
			merchant.bubble.hide()
	print("BUBBLE_CHECK_OK: Vietnamese and English text fits every merchant bubble at size 12")
	world.free()
	get_tree().quit()
