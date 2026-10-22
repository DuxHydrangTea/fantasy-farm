extends GutTest
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const MERCHANT: PackedScene = preload("res://scenes/characters/shop_merchant.tscn")
var viewport: SubViewport
var player: FarmPlayer
var merchant: ShopMerchant

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	viewport.add_child(player)
	merchant = MERCHANT.instantiate() as ShopMerchant
	merchant.position = Vector2(24, 0)
	viewport.add_child(merchant)
	await wait_process_frames(2)

func after_each() -> void:
	Language.set_language("en")
	await wait_process_frames(2)

func test_english_default_and_live_inventory_hotbar_wallet_and_tooltips() -> void:
	assert_eq(TranslationServer.get_locale(), "en")
	var bag: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	bag.open()
	bag._inspect_slot(1)
	var before: Array[Dictionary] = []
	for index: int in range(player.selection.inventory.slot_count):
		before.append(player.selection.inventory.slot(index))
	assert_eq(hotbar.selected_name.text, "Watering Can")
	assert_string_contains(bag.details.text, "Watering Can")
	assert_string_contains(bag.capacity.text, "slots")
	assert_true(Language.set_language("vi"))
	await wait_process_frames(3)
	assert_eq(hotbar.selected_name.text, "Bình tưới")
	assert_string_contains(bag.details.text, "Bình tưới")
	assert_string_contains(bag.capacity.text, "ô")
	assert_eq(bag.buttons[1].tooltip_text, "Bình tưới")
	assert_eq(bag.wallet_label.text, "1.000 xu")
	assert_true(bag.root.visible)
	assert_eq(bag.inspected_index, 1)
	assert_eq(player.selection.selected_index, 1)
	assert_true(Language.set_language("en"))
	await wait_process_frames(3)
	assert_eq(hotbar.selected_name.text, "Watering Can")
	assert_eq(bag.wallet_label.text, "1,000 coins")
	for index: int in range(before.size()):
		assert_eq(player.selection.inventory.slot(index), before[index], "Changing language never changes inventory data")
	assert_false(Language.set_language("unsupported"))
	assert_eq(TranslationServer.get_locale(), "en")

func test_shop_retranslates_scene_and_generated_cards_without_changing_checkout() -> void:
	assert_true(merchant.open_shop(player))
	var shop: ShopUI = merchant.shop_ui
	shop.show_category(ShopOffer.Category.FEED)
	var offer: ShopOffer = merchant.catalog.offers.filter(func(entry: ShopOffer) -> bool: return entry.category == ShopOffer.Category.FEED and entry.item.item_id == &"livestock_feed")[0]
	shop.select_offer(offer)
	shop.quantity.value = 3
	assert_string_contains(shop.details.text, "Livestock Feed")
	assert_string_contains(shop.buy_button.text, "Buy ×3")
	Language.set_language("vi")
	await wait_process_frames(3)
	assert_eq(shop.selected, offer)
	assert_eq(shop.quantity.value, 3.0)
	assert_string_contains(shop.details.text, "Thức ăn gia súc")
	assert_string_contains(shop.buy_button.text, "Mua ×3")
	assert_eq((shop.categories.get_child(1) as Button).text, "Farm supplies", "Scene text stays an English source key; Godot translates it at draw time")
	assert_eq(tr((shop.categories.get_child(1) as Button).text), "Đồ dùng nông trại")
	assert_true(shop.grid.get_children().any(func(card: Node) -> bool: return (card as Button).tooltip_text == "Thức ăn gia súc"))
	assert_true(player.selection.shop_open)
	assert_eq(player.wallet.balance, 1000)
	Language.set_language("en")
	await wait_process_frames(3)
	assert_eq(shop.selected, offer)
	assert_string_contains(shop.details.text, "Livestock Feed")
	assert_string_contains(shop.buy_button.text, "Buy ×3")
	shop.close()
	assert_false(merchant.bubble.visible, "Translation refresh is never a purchase")

func test_animal_sale_selection_survives_language_change() -> void:
	var pen: AnimalPen = AnimalPen.new()
	pen.accepted_species = [AnimalTypes.Species.CHICKEN]
	viewport.add_child(pen)
	await wait_physics_frames(2)
	merchant.open_shop(player)
	var shop: ShopUI = merchant.shop_ui
	shop.show_category(ShopOffer.Category.ANIMAL)
	shop.purchase()
	var animal: AnimalActor = shop.animal_service.owned_animals()[0]
	shop.show_category(ShopOffer.Category.SELL_ANIMAL)
	shop.select_animal(animal)
	assert_string_contains(shop.details.text, "Chicken")
	Language.set_language("vi")
	await wait_process_frames(3)
	assert_eq(shop.selected_animal, animal)
	assert_false(shop.buy_button.disabled)
	assert_string_contains(shop.details.text, "Gà")
	assert_string_contains(shop.details.text, "Con non")
	assert_eq(player.wallet.balance, 840)
	Language.set_language("en")
	await wait_process_frames(3)
	assert_eq(shop.selected_animal, animal)
	assert_string_contains(shop.details.text, "Chicken")
	assert_string_contains(shop.details.text, "Young")
	assert_string_contains(shop.buy_button.text, "80 coins")

func test_backend_errors_keep_source_keys_and_localize_only_for_display() -> void:
	var result: Dictionary = SaveSchema.failure("Invalid list: {list}", "invalid", {"list": "crops"})
	assert_eq(GameText.error(result), "Invalid list: crops")
	Language.set_language("vi")
	assert_eq(GameText.error(result), "Danh sách không hợp lệ: crops")
	assert_eq(result.error, "Invalid list: {list}")
	assert_eq(result.code, "invalid")
	assert_eq(result.error_values, {"list": "crops"})

func test_catalog_placeholders_and_vietnamese_font_coverage() -> void:
	var english: Translation = load("res://localization/en.po") as Translation
	var vietnamese: Translation = load("res://localization/vi.po") as Translation
	assert_not_null(english)
	assert_not_null(vietnamese)
	assert_gt(english.get_message_list().size(), 200)
	var placeholders: RegEx = RegEx.new()
	assert_eq(placeholders.compile("\\{[^{}]+\\}"), OK)
	var font: Font = load("res://resources/ui/game_font.tres") as Font
	var seen: Dictionary = {}
	for source: String in english.get_message_list():
		var translated: String = vietnamese.get_message(source)
		assert_false(translated.is_empty(), "Missing Vietnamese translation: " + source)
		var expected: Array[String] = []
		var actual: Array[String] = []
		for match_result: RegExMatch in placeholders.search_all(source):
			expected.append(match_result.get_string())
		for match_result: RegExMatch in placeholders.search_all(translated):
			actual.append(match_result.get_string())
		expected.sort()
		actual.sort()
		assert_eq(actual, expected, source)
		for character: String in translated:
			if character not in ["\n", "\r", "\t"] and not seen.has(character):
				seen[character] = true
				assert_true(_has_glyph(font, character.unicode_at(0)), "Missing glyph: " + character)

func _has_glyph(font: Font, codepoint: int) -> bool:
	if font.has_char(codepoint):
		return true
	for fallback: Font in font.fallbacks:
		if _has_glyph(fallback, codepoint):
			return true
	return false
