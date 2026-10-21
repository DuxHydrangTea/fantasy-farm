class_name LandPurchaseUI
extends TradeMenu
## Small modal adapted from the skill pause-menu skeleton and shared TradeMenu.
var expansion: LandExpansionComponent
var description: Label
var status: Label
var confirm: Button
var panel: PanelContainer
var _quoted_columns: int = 0

func _ready() -> void:
	_build()
	super._ready()
	models_changed.connect(_refresh)
	root.resized.connect(_fit)
	_fit()

func _build() -> void:
	layer = 26
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.08, 0.08, 0.06, 0.7)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = preload("res://resources/ui/inventory_panel.tres")
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(edge, 6.0)
		style.set_content_margin(edge, 20.0)
	panel.add_theme_stylebox_override("panel", style)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var title: Label = Label.new()
	title.text = "RECLAIM FARMLAND"
	body.add_child(title)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	body.add_child(buttons)
	confirm = Button.new()
	confirm.custom_minimum_size.y = 44
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.text = "Reclaim"
	confirm.pressed.connect(_buy)
	buttons.add_child(confirm)
	close_button = Button.new()
	close_button.text = "Cancel"
	close_button.custom_minimum_size = Vector2(100, 44)
	buttons.add_child(close_button)

func _fit() -> void:
	panel.custom_minimum_size.x = minf(560.0, maxf(280.0, root.size.x - 32.0))

func open_offer(player: FarmPlayer) -> bool:
	if not super.open(null, player):
		return false
	_quoted_columns = expansion.state.unlocked_columns
	_refresh()
	close_button.grab_focus()
	return true

func _refresh() -> void:
	if not is_open:
		return
	var price: int = expansion.state.next_price()
	description.text = tr("Spend {price} coins to reclaim the next column ({plots} plots)?").format({"price": price, "plots": LandExpansionState.REGION.size.y})
	status.text = tr("Unlocked: {owned}/{columns} columns · Balance: {coins} coins").format({"owned": expansion.state.unlocked_columns, "columns": LandExpansionState.REGION.size.x, "coins": customer.wallet.balance})
	if customer.wallet.balance < price:
		status.text += "\n" + tr("Not enough coins.")
	confirm.disabled = customer.wallet.balance < price or expansion.state.is_complete()

func _buy() -> void:
	if not is_open:
		return
	var result: Dictionary = expansion.purchase(_quoted_columns)
	if result.ok:
		close(false)
	else:
		_refresh()
		status.text = GameText.error(result)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
