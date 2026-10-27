class_name ToolUpgradeShopView
extends RefCounted
## Reusable vendor view; transactions remain in the profile's upgrade service.
const ICONS: Dictionary = {&"hoe": preload("res://items/tools/hoe.tres"), &"watering_can": preload("res://items/tools/watering_can.tres"), &"sowing": preload("res://items/seeds/carrot_seed.tres")}
const TITLES: Dictionary = {&"hoe": "Hoe", &"watering_can": "Watering Can", &"sowing": "Sowing"}
var shop: ShopUI
var upgrades: ToolUpgradeService
var world: FarmWorld
var selected: StringName = &"hoe"
var _quote: Dictionary = {}

func _init(view: ShopUI, service: ToolUpgradeService, farm: FarmWorld) -> void:
	shop = view
	upgrades = service
	world = farm

func build() -> void:
	for tool: StringName in ToolUpgradeState.TOOLS:
		shop._card(ICONS[tool].icon, tr(TITLES[tool]), 0, tool, select.bind(tool))
		(shop._buttons[tool] as Button).custom_minimum_size.y = 176
	refresh()

func select(tool: StringName) -> void:
	selected = tool
	refresh()

func refresh() -> void:
	shop.present_product(ICONS[selected].icon, tr(TITLES[selected]), tr("Tool upgrades"))
	if upgrades == null:
		shop.details.text = tr("Tool upgrades are unavailable.")
		shop.buy_button.disabled = true
		return
	for tool: StringName in ToolUpgradeState.TOOLS:
		var level: int = upgrades.state.level(tool)
		var next: ToolUpgradeOffer = upgrades.catalog.find(tool, level + 1)
		var label: Label = shop._price_labels[tool] as Label
		label.add_theme_font_size_override("font_size", 16)
		label.text = tr("Level %d · %d×%d") % [level, level, level]
		label.text += "\n" + (tr("Maximum level") if next == null else tr("{coins} coins").format({"coins": next.price}))
		if next != null and next.wood_cost > 0:
			label.text += "\n" + tr("Wood: {count}").format({"count": next.wood_cost})
		(shop._buttons[tool] as Button).set_pressed_no_signal(tool == selected)
	_quote = upgrades.quote(selected)
	var level: int = upgrades.state.level(selected)
	var next: ToolUpgradeOffer = upgrades.catalog.find(selected, level + 1)
	shop.details.text = tr(TITLES[selected]) + "\n" + (tr("Maximum level") if next == null else "%d×%d → %d×%d" % [level, level, level + 1, level + 1])
	shop.details.text += "\n" + tr("Balance: {coins} coins").format({"coins": upgrades.wallet.balance})
	if selected == &"sowing":
		shop.details.text += "\n" + tr("Applies to all crop seeds.")
	if next != null:
		shop.details.text += "\n" + tr("Land purchased: {owned} columns · Required: {required}").format({"owned": upgrades.land.unlocked_columns - upgrades.land.starting_columns, "required": next.required_purchased_columns})
	if next != null:
		shop.details.text += "\n" + tr("Wood: {owned}/{required} · Warehouse first, then bag (Normal)").format({"owned": upgrades.wood_owned(), "required": next.wood_cost})
	shop.buy_button.text = tr("Maximum level") if next == null else tr("Upgrade - {coins} coins").format({"coins": next.price})
	if next != null and next.wood_cost > 0:
		shop.buy_button.text += " + " + tr("Wood: {count}").format({"count": next.wood_cost})
	shop.buy_button.disabled = not _quote.ok
	shop.status.text = tr("Unlock a larger area. Each planted cell still uses one seed.") if _quote.ok else GameText.error(_quote)

func purchase() -> void:
	var offered: Dictionary = _quote.duplicate()
	if upgrades == null or not offered.get("ok", false):
		refresh()
		return
	var result: Dictionary = upgrades.purchase(selected, int(offered.current_level), int(offered.price), int(offered.wood_cost))
	refresh()
	if result.ok:
		shop.bought_this_visit = true
		shop.status.text = tr("Upgraded {tool} to {size}×{size}!").format({"tool": tr(TITLES[selected]), "size": result.level})
		_save_progress.call_deferred()
	else:
		shop.status.text = GameText.error(result)

func _save_progress() -> void:
	if SaveManager.adapter != null and SaveManager.adapter.world == world and SaveManager.writes_enabled and not SaveManager.busy:
		SaveManager.save_game()
