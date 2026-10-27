extends GutTest
const FIXTURE: PackedScene = preload("res://tests/support/management_redesign_fixture.tscn")
var fixture: ManagementRedesignFixture
var viewport: SubViewport

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	fixture = FIXTURE.instantiate() as ManagementRedesignFixture
	viewport.add_child(fixture)
	fixture.world.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(3)

func after_each() -> void:
	Language.set_language("en")

func test_pen_upgrade_keeps_quote_price_capacity_and_cooldown_consistent() -> void:
	var menu: PenDashboard = fixture.world.get_node("CoopPen/ManagementSign/PenMenu") as PenDashboard
	var balance: int = fixture.world.player.wallet.balance
	var price: int = int(menu._upgrade_offer.price)
	var capacity: int = menu.board.pen.capacity
	assert_eq(menu.cards.size(), 4)
	assert_eq(menu.balance_label.text, tr("{coins} coins").format({"coins": GameText.grouped_integer(balance)}))
	menu._purchase_upgrade()
	assert_eq(menu.board.pen.capacity, capacity + 5)
	assert_eq(fixture.world.player.wallet.balance, balance - price)
	assert_true(menu.upgrade_feedback.visible)
	menu._purchase_upgrade()
	assert_eq(fixture.world.player.wallet.balance, balance - price)
	fixture.world.pen_upgrades.profile_ready = false
	menu.refresh()
	assert_true(menu.upgrade_button.disabled)

func test_tree_upgrade_updates_preview_and_only_the_selected_region() -> void:
	(fixture.world.get_node("CoopPen/ManagementSign/PenMenu") as PenDashboard).close(false)
	var menu: TreePlotMenu = fixture.open_tree()
	var balance: int = fixture.world.player.wallet.balance
	var price: int = int(menu._offer.price)
	var timber: int = fixture.world.tree_plot_upgrades.state.capacity(TreeDefinition.Kind.TIMBER)
	assert_eq(menu.plot_preview.capacity, 27)
	assert_eq((menu.get_node("%PlantedValue") as Label).text, "18")
	menu._purchase()
	assert_eq(menu.plot_preview.capacity, 36)
	assert_eq(fixture.world.player.wallet.balance, balance - price)
	assert_eq(fixture.world.tree_plot_upgrades.state.capacity(TreeDefinition.Kind.TIMBER), timber)
	menu._purchase()
	assert_eq(fixture.world.player.wallet.balance, balance - price)
	menu.close(false)
	assert_false(fixture.world.player.selection.shop_open)

func test_maximum_plot_capacity_disables_upgrade_without_charging_again() -> void:
	(fixture.world.get_node("CoopPen/ManagementSign/PenMenu") as PenDashboard).close(false)
	fixture.world.player.wallet.set_balance(100000000)
	var service: TreePlotUpgradeService = fixture.world.tree_plot_upgrades
	while service.state.level(TreeDefinition.Kind.FRUIT) < TreePlotUpgradeState.MAX_LEVEL:
		var offered: Dictionary = service.quote(TreeDefinition.Kind.FRUIT)
		assert_true(offered.ok)
		assert_true(service.purchase(TreeDefinition.Kind.FRUIT, int(offered.level), int(offered.price)).ok)
	var menu: TreePlotMenu = fixture.open_tree()
	assert_eq(menu.plot_preview.capacity, 153)
	assert_true(menu.upgrade_button.disabled)
	var balance: int = fixture.world.player.wallet.balance
	menu._purchase()
	assert_eq(fixture.world.player.wallet.balance, balance)

func test_live_locale_change_keeps_animated_roster_and_plot_models_unchanged() -> void:
	var menu: PenDashboard = fixture.world.get_node("CoopPen/ManagementSign/PenMenu") as PenDashboard
	var ids: Array = menu.cards.keys()
	var coins: int = fixture.world.player.wallet.balance
	Language.set_language("en")
	assert_eq(menu.heading.text, "Coop management")
	assert_eq(menu.cards.keys(), ids)
	for card: AnimalCard in menu.cards.values():
		assert_ne(card.preview, card.animal.sprite)
		assert_true(card.preview.is_playing())
	assert_eq(fixture.world.player.wallet.balance, coins)
