extends "res://tests/support/hotbar_skin_probe.gd"

func _layout(shop: ShopUI) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	for control: Control in [shop.panel, shop.balance_label, shop.close_button, shop.buy_button, shop.quantity, shop.total_price]:
		_check(bounds.encloses(_screen_rect(control)), "Checkout stays on screen: " + control.name)
	_check(not _screen_rect(shop.browse).intersects(_screen_rect(shop.sidebar)), "Catalog and sidebar stay separate")
	_check(shop.buy_button.size.y >= 48, "Buy keeps a 48px target")
	for child: Node in shop.quantity.get_children():
		if child is TouchQuantityComponent:
			var stepper: TouchQuantityComponent = child as TouchQuantityComponent
			_check(stepper.decrease.visible and stepper.increase.visible, "Quantity buttons are visible")
			_check(bounds.encloses(_screen_rect(stepper.increase)), "Quantity plus stays on screen")

func _run() -> void:
	Language.set_language("vi")
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(8)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(100000)
	var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	world.player.global_position = merchant.interaction_position() + Vector2(0, 20)
	_check(merchant.open_shop(world.player), "Real vendor opens redesigned shop")
	var shop: ShopUI = merchant.shop_ui
	var offer: ShopOffer
	for entry: ShopOffer in merchant.catalog.offers:
		if entry.item == SEED:
			offer = entry
	shop.select_offer(offer)
	shop.quantity.value = 5
	await _frames(8)
	_layout(shop)
	_check(shop.grid.columns == 4, "Desktop catalog has four columns")
	await _capture("shop-desktop-vi")
	var before: int = world.player.selection.inventory.count_item(SEED.item_id)
	await _click(shop.buy_button)
	_check(world.player.wallet.balance == 100000 - 5 * offer.price, "Purchase charges the displayed quantity")
	_check(world.player.selection.inventory.count_item(SEED.item_id) == before + 5, "Purchase adds all seeds")
	_check(shop.owned_count.text == str(before + 5), "Owned count updates after purchase")
	Language.set_language("en")
	await _frames(6)
	_check(shop.product_name.text == tr(SEED.display_name), "Product title translates live")
	_check((shop.categories.get_child(0) as Button).text == "Crop seeds", "Category tabs translate live")
	await _capture("shop-desktop-en")
	shop.show_category(ShopUI.UPGRADES)
	await _frames(4)
	_check(not shop.quantity.visible and not shop.total_row.visible, "Upgrade hides quantity and purchase total")
	await _capture("shop-upgrades-desktop")
	Language.set_language("vi")
	get_viewport().set_meta("touch_ui_override", true)
	get_viewport().set_meta("safe_insets", Vector4(44, 0, 44, 21))
	get_tree().root.size = Vector2i(844, 390)
	shop.show_category(ShopOffer.Category.CROP)
	shop.select_offer(offer)
	shop.quantity.value = 1
	await _frames(10)
	_layout(shop)
	for child: Node in shop.quantity.get_children():
		if child is TouchQuantityComponent:
			await _touch_click((child as TouchQuantityComponent).increase)
	_check(shop.quantity.value == 2, "Touch plus changes quantity without keyboard")
	await _capture("shop-phone-vi")
	await _touch_click(shop.buy_button)
	_check(world.player.selection.inventory.count_item(SEED.item_id) == before + 7, "Touch buys the selected quantity")
	world.player.wallet.set_balance(0)
	_check(shop.buy_button.disabled, "Insufficient coins disables purchase")
	_check(shop.buy_button.text == tr("Not enough coins."), "Compact checkout shows the failure reason directly")
	await _capture("shop-insufficient-phone")
	get_viewport().set_meta("safe_insets", Vector4.ZERO)
	get_tree().root.size = Vector2i(667, 375)
	await _frames(8)
	_layout(shop)
	shop.browse.ensure_control_visible(shop.grid.get_child(shop.grid.get_child_count() - 1) as Control)
	await _frames(5)
	_check(_screen_rect(shop.browse).grow(1).encloses(_screen_rect(shop.grid.get_child(shop.grid.get_child_count() - 1) as Control)), "Last offer is reachable by scrolling")
	await _capture("shop-small-phone")
	for index: int in range(shop.categories.get_child_count()):
		shop.show_category(index)
		await _frames(2)
		_check(get_viewport().get_visible_rect().grow(1).encloses(_screen_rect(shop.panel)), "Category stays on screen: " + str(index))
	shop.close(false)
	_check(not world.player.selection.shop_open, "Closing releases modal lock")
	var report: Dictionary = {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/runtime-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
