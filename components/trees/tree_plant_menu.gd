class_name TreePlantMenu
extends TradeMenu
## Giao diện chọn và mua trực tiếp cây ăn quả hoặc cây lấy gỗ tại ô đất trống.

const SPRITE_SIZE: Vector2 = Vector2(64, 80)

var world: FarmWorld
var _cell: Vector2i = Vector2i.ZERO
var _kind: TreeDefinition.Kind = TreeDefinition.Kind.TIMBER
var _selected: TreeDefinition
var _last_selected: Dictionary = {}
var _buttons: Dictionary = {}
var _yield_row: VisualValueRow
var _compact: bool = false

@onready var panel: PanelContainer = %Panel
@onready var body: VBoxContainer = %Body
@onready var main_row: HBoxContainer = %Main
@onready var heading: Label = %Heading
@onready var balance_label: Label = %Balance
@onready var browse: ScrollContainer = %Browse
@onready var grid: GridContainer = %Grid
@onready var sidebar: VBoxContainer = %Sidebar
@onready var preview_frame: PanelContainer = %PreviewFrame
@onready var tree_preview: TextureRect = %TreePreview
@onready var tree_name: Label = %TreeName
@onready var tree_type: Label = %TreeType
@onready var details: Label = %Details
@onready var status: Label = %Status
@onready var price_title: Label = %PriceTitle
@onready var price_value: Label = %PriceValue
@onready var buy_button: Button = %BuyButton
@onready var hint: Label = %Hint

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	VisualValueRow.money(balance_label)
	VisualValueRow.money(price_value)
	_yield_row = VisualValueRow.before(details)
	_yield_row.hide()
	models_changed.connect(_refresh)
	root.resized.connect(_fit)
	buy_button.pressed.connect(purchase)
	_fit()

## Mở menu chọn cây cho ô đất trống và loại khu cây tương ứng.
func open_plot(cell: Vector2i, kind: TreeDefinition.Kind) -> bool:
	if is_open or world == null or world.trees == null or world.player == null:
		return false
	_cell = cell
	_kind = kind
	if not super.open(null, world.player):
		return false
	_rebuild_grid()
	browse.scroll_vertical = 0
	_fit()
	_refresh()
	var focus_target: Button = _buttons.get(_selected) as Button
	if focus_target != null:
		focus_target.grab_focus()
	else:
		close_button.grab_focus()
	return true

func _rebuild_grid() -> void:
	for child: Node in grid.get_children():
		child.free()
	_buttons.clear()
	var definitions: Array[TreeDefinition] = world.trees.definitions_for(_kind)
	var preferred_id: StringName = _last_selected.get(_kind, &"") as StringName
	_selected = null
	for definition: TreeDefinition in definitions:
		_add_card(definition)
		if _selected == null or definition.tree_id == preferred_id:
			_selected = definition

func _add_card(definition: TreeDefinition) -> void:
	var card: Button = Button.new()
	card.name = "TreeCard_%s" % String(definition.tree_id)
	card.custom_minimum_size = Vector2(96, 140) if _compact else Vector2(112, 148)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.tooltip_text = tr(definition.display_name)
	var card_body: VBoxContainer = VBoxContainer.new()
	card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_theme_constant_override("separation", 2)
	card.add_child(card_body)
	card_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_body.offset_left = 6
	card_body.offset_top = 5
	card_body.offset_right = -6
	card_body.offset_bottom = -6
	var sprite_rect: TextureRect = TextureRect.new()
	sprite_rect.name = "TreeSprite"
	sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_rect.custom_minimum_size = SPRITE_SIZE
	sprite_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_rect.texture = definition.ready_texture
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_body.add_child(sprite_rect)
	var name_label: Label = Label.new()
	name_label.text = tr(definition.display_name)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14 if _compact else 15)
	card_body.add_child(name_label)
	var price_label: Label = Label.new()
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	price_label.add_theme_font_size_override("font_size", 14 if _compact else 15)
	price_label.text = GameText.grouped_integer(definition.price)
	card_body.add_child(price_label)
	VisualValueRow.money(price_label)
	var coin_row: HBoxContainer = price_label.get_meta(&"coin_row") as HBoxContainer
	if coin_row != null:
		coin_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		price_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pressed.connect(_select_tree.bind(definition))
	grid.add_child(card)
	_buttons[definition] = card

func _select_tree(definition: TreeDefinition) -> void:
	if not is_open or definition == null:
		return
	_selected = definition
	_refresh()

func _refresh() -> void:
	if not is_open:
		return
	heading.text = tr("Plant fruit tree") if _kind == TreeDefinition.Kind.FRUIT else tr("Plant timber tree")
	balance_label.text = GameText.grouped_integer(customer.wallet.balance)
	price_title.text = tr("Price")
	hint.text = tr("Choose a tree to plant on this plot. Esc / E / Tab to close.")
	for definition: Variant in _buttons:
		(_buttons[definition] as Button).set_pressed_no_signal(definition == _selected)
	if _selected == null:
		_yield_row.hide()
		preview_frame.hide()
		tree_preview.texture = null
		tree_name.text = tr("No trees available.")
		tree_type.text = ""
		details.text = tr("No trees available.")
		status.text = ""
		status.hide()
		price_value.text = "—"
		buy_button.text = tr("Buy & plant")
		buy_button.disabled = true
		return
	preview_frame.show()
	tree_preview.texture = _selected.ready_texture
	tree_name.text = tr(_selected.display_name)
	tree_type.text = tr("Fruit tree") if _selected.kind == TreeDefinition.Kind.FRUIT else tr("Timber tree")
	if _selected.harvest_item != null:
		var yield_caption: String = "× %s / %s" % [GameText.grouped_integer(_selected.harvest_amount), _duration(_selected.fruit_cycle_seconds)] if _selected.kind == TreeDefinition.Kind.FRUIT else "× %s" % GameText.grouped_integer(_selected.harvest_amount)
		_yield_row.show_item(_selected.harvest_item, yield_caption)
	else:
		_yield_row.hide()
	var lines: PackedStringArray = [
		tr("Growth time: {time}").format({"time": _duration(_selected.growth_seconds)}),
		tr("Fruit cycle: {time}").format({"time": _duration(_selected.fruit_cycle_seconds)}) if _selected.kind == TreeDefinition.Kind.FRUIT else tr("Regrows from stump in {time}").format({"time": _duration(_selected.growth_seconds * 0.5)}),
		tr("Water once after planting to start growth.") if _selected.kind == TreeDefinition.Kind.FRUIT else tr("Starts growing immediately. Chop mature trees with an axe.")
	]
	details.text = "\n".join(lines)
	var checked: Dictionary = world.trees.quote_buy(_cell, _selected, customer.wallet)
	price_value.text = GameText.grouped_integer(_selected.price)
	buy_button.text = tr("Buy & plant")
	buy_button.disabled = not bool(checked.ok)
	status.text = "" if bool(checked.ok) else GameText.error(checked)
	status.visible = not status.text.is_empty()
	buy_button.tooltip_text = status.text

## Mua và trồng cây đang chọn trực tiếp lên ô đất mục tiêu.
func purchase() -> void:
	if not is_open or _selected == null or world == null or world.trees == null:
		return
	var result: Dictionary = world.trees.purchase_and_plant(_cell, _selected, customer.wallet, world.farming.time_manager.now())
	Sound.result(result, &"coin_spend")
	if result.ok:
		bought_this_visit = true
		Sound.play(&"sow_seed")
		_last_selected[_kind] = _selected.tree_id
		_save.call_deferred()
		close(false)
	else:
		_refresh()
		status.text = GameText.error(result)
		status.visible = not status.text.is_empty()

func _save() -> void:
	var manager: GameSaveManager = get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

func _process(_delta: float) -> void:
	if not is_open:
		return
	if world == null or world.trees == null or world.trees.trees.has(_cell) or not is_instance_valid(customer) or customer.global_position.distance_to(world.trees.point_for(_cell)) > 48.0:
		close(false)

func _fit() -> void:
	if panel == null:
		return
	var view: Vector2 = root.size
	var short: bool = view.y < 330 and not MobileLayout.is_touch(get_viewport())
	_compact = view.x < 800.0 or view.y < 500.0 or MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(1100.0, maxf(0.0, view.x - 32.0)), minf(620.0, maxf(0.0, view.y - (16.0 if _compact else 24.0))))
	body.add_theme_constant_override("separation", 4 if _compact else 12)
	main_row.add_theme_constant_override("separation", 8 if _compact else 12)
	sidebar.custom_minimum_size.x = 224 if _compact else 300
	sidebar.add_theme_constant_override("separation", 4 if _compact else 8)
	heading.add_theme_font_size_override("font_size", 20 if _compact else 26)
	balance_label.add_theme_font_size_override("font_size", 16 if _compact else 18)
	tree_preview.custom_minimum_size = SPRITE_SIZE
	tree_name.add_theme_font_size_override("font_size", 18 if _compact else 22)
	tree_type.add_theme_font_size_override("font_size", 15 if _compact else 18)
	details.add_theme_font_size_override("font_size", 15 if _compact else 18)
	status.add_theme_font_size_override("font_size", 15 if _compact else 18)
	buy_button.custom_minimum_size.y = 36 if short else 48
	close_button.custom_minimum_size.y = 36 if short else 48
	buy_button.add_theme_font_size_override("font_size", 16 if _compact else 18)
	hint.visible = not _compact
	var card_width: float = 96.0 if _compact else 112.0
	var card_height: float = 140.0 if _compact else 148.0
	var width: float = panel.custom_minimum_size.x - 32.0 - sidebar.custom_minimum_size.x - 26.0 - 16.0
	grid.columns = clampi(floori((width + 8.0) / (card_width + 8.0)), 2, 6)
	for definition: Variant in _buttons:
		var card: Button = _buttons[definition] as Button
		card.custom_minimum_size = Vector2(card_width, card_height)
		var card_body: VBoxContainer = card.get_child(0) as VBoxContainer
		(card_body.get_child(0) as TextureRect).custom_minimum_size = SPRITE_SIZE
		(card_body.get_child(1) as Label).add_theme_font_size_override("font_size", 14 if _compact else 15)
		var coin_row: HBoxContainer = card_body.get_child(2) as HBoxContainer
		if coin_row != null and coin_row.get_child_count() > 1 and coin_row.get_child(1) is Label:
			(coin_row.get_child(1) as Label).add_theme_font_size_override("font_size", 14 if _compact else 15)
	if MobileLayout.is_touch(get_viewport()):
		MobileLayout.prepare_buttons(root)
	if is_open:
		_refresh()

func _duration(seconds: float) -> String:
	var minutes: int = ceili(maxf(0.0, seconds) / 60.0)
	if minutes < 60:
		return tr("{minutes} min").format({"minutes": minutes})
	var hours: int = ceili(minutes / 60.0)
	return tr("{days}d {hours}h").format({"days": hours / 24, "hours": hours % 24}) if hours >= 24 else tr("{hours}h").format({"hours": hours})

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_open:
		_rebuild_grid()
		_fit()
		_refresh()
