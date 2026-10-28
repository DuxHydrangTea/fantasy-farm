extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var viewport: SubViewport
var world: FarmWorld
var merchant: ShopMerchant
var shop: ShopUI

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(world)
	world.storages.inventory("produce_warehouse").add(load("res://items/trees/wood.tres") as ItemDefinition, 1000)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(10000000)
	world.land.state.restore_columns(13, 4)
	merchant = world.get_node("BlacksmithMerchant") as ShopMerchant
	shop = merchant.shop_ui
	world.player.global_position = merchant.interaction_position() + Vector2(0, 20)
	assert_true(merchant.open_shop(world.player))
	shop.show_category(ShopUI.UPGRADES)
	await wait_process_frames(3)

func test_existing_vendor_exposes_three_upgrade_cards_and_sequential_purchases() -> void:
	assert_eq(shop._category_tabs.values().filter(func(tab: Button) -> bool: return tab.visible).size(), 3)
	assert_eq(shop.grid.get_child_count(), 3)
	assert_false(shop.quantity.visible)
	for tool: StringName in ToolUpgradeState.TOOLS:
		shop.upgrade_view.select(tool)
		assert_false(shop.buy_button.disabled)
		for level: int in range(2, 7):
			shop.purchase()
			assert_eq(world.tool_upgrade_state.level(tool), level)
		assert_true(shop.buy_button.disabled)
		var balance: int = world.player.wallet.balance
		shop.purchase()
		assert_eq(world.player.wallet.balance, balance)
	assert_eq(world.player.wallet.balance, 6500000)
	assert_true(shop.bought_this_visit)

func test_money_land_and_loading_guards_disable_the_checkout() -> void:
	world.player.wallet.set_balance(0)
	shop._refresh()
	assert_true(shop.buy_button.disabled)
	shop.purchase()
	assert_eq(world.tool_upgrade_state.level(&"hoe"), 1)
	world.player.wallet.set_balance(1000000)
	world.land.state.restore_columns(4, 4)
	shop._refresh()
	assert_true(shop.buy_button.disabled)
	world.land.state.restore_columns(7, 4)
	world.tool_upgrades.profile_ready = false
	shop._refresh()
	assert_true(shop.buy_button.disabled)

func test_other_shop_categories_and_modal_lifecycle_still_work() -> void:
	shop.show_category(ShopOffer.Category.TOOLS)
	assert_true(shop.quantity.visible)
	assert_eq(shop.grid.get_child_count(), 3)
	shop.show_category(ShopUI.UPGRADES)
	assert_true(world.player.selection.shop_open)
	world.player.tool_range_ui.cycle()
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 1)
	shop.close(false)
	assert_false(world.player.selection.shop_open)

func test_range_selector_cycles_only_unlocked_sizes_and_locks_during_action() -> void:
	shop.purchase()
	shop.purchase()
	shop.close(false)
	world.player.selection.select_slot(0)
	var range_ui: ToolRangeUI = world.player.tool_range_ui
	range_ui.cycle()
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 1)
	range_ui.cycle()
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 2)
	world.player.state.transition_to(StateComponent.State.TOOL)
	range_ui.cycle()
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 2)
	world.player.state.transition_to(StateComponent.State.IDLE)
	world.player.selection.set_inventory_open(true)
	range_ui.cycle()
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 2)

func test_landscape_touch_layout_and_secondary_finger_range_control() -> void:
	viewport.size = Vector2i(844, 390)
	viewport.set_meta(&"touch_layout", true)
	viewport.set_meta(&"ui_point_scale", 1.0)
	shop._fit_layout()
	await wait_process_frames(4)
	assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(shop.panel.get_global_rect()))
	for child: Node in shop.quantity.get_children():
		if child is TouchQuantityComponent:
			assert_false(child.increase.visible)
			assert_false(child.decrease.visible)
	shop.purchase()
	shop.close(false)
	world.player.selection.select_slot(0)
	world.player.tool_range_ui._process(0.0)
	var button: Button = world.player.tool_range_ui.button
	assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(button.get_global_rect()))
	assert_true(world.player.mobile_controls._press_hotbar(button.get_global_transform_with_canvas() * (button.size * 0.5)))
	assert_eq(world.tool_upgrade_state.selected_size(&"hoe"), 1)
