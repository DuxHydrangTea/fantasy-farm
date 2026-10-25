class_name CookingMenu
extends TradeMenu
## Container-based Chef view using the shared modal and UI scale lifecycle.
var world: FarmWorld
var panel: PanelContainer
var summary: Label
var details: Label
var status: Label
var cook_button: Button
var collect_button: Button
var quantity: SpinBox
var browse: ScrollContainer
var recipe_buttons: Array[Button] = []
var selected: CookingRecipe = ChefCooking.RECIPES[0]
var _elapsed: float = 0.0
var _message: String = ""

func _ready() -> void:
	layer = 25
	_build()
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(_refresh)
	root.resized.connect(_queue_fit)
	panel.minimum_size_changed.connect(_queue_fit)
	_fit()

func _label(parent: Node) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build() -> void:
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.75)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	var style: StyleBox = root.theme.get_stylebox(&"panel", &"PanelContainer").duplicate() as StyleBox
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, 12)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	var title: Label = _label(header)
	title.text = tr("Chef Chloe · Cooking")
	close_button = _button(header, "×", func() -> void: pass)
	var scroll: ScrollContainer = ScrollContainer.new()
	browse = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	body.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	summary = _label(content)
	var list: GridContainer = GridContainer.new()
	list.columns = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(list)
	for recipe: CookingRecipe in ChefCooking.RECIPES:
		var button: Button = _button(list, tr(recipe.display_name), _select.bind(recipe))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = recipe.output.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.clip_text = true
		button.toggle_mode = true
		recipe_buttons.append(button)
	details = _label(content)
	var row: HBoxContainer = HBoxContainer.new()
	content.add_child(row)
	var amount_label: Label = _label(row)
	amount_label.text = tr("Dishes to queue")
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = ChefCooking.CAPACITY
	quantity.custom_minimum_size = Vector2(120, 44)
	row.add_child(quantity)
	quantity.value_changed.connect(func(_value: float) -> void: _refresh())
	TouchQuantityComponent.attach(quantity, root)
	status = _label(content)
	cook_button = _button(body, tr("Give ingredients & cook"), _cook)
	collect_button = _button(body, tr("Collect ready dishes"), _collect)

func _fit() -> void:
	panel.size = Vector2(minf(760, root.size.x - 24), minf(580, root.size.y - 24))
	panel.position = (root.size - panel.size) * 0.5

func _queue_fit() -> void:
	# Wrapping labels update container minimums after a viewport resize.
	_fit.call_deferred()

func _visit() -> void:
	world = customer.get_parent() as FarmWorld
	_message = ""
	quantity.value = 1
	_refresh()
	_queue_fit()

func _select(recipe: CookingRecipe) -> void:
	selected = recipe
	_message = ""
	_refresh()

func _available() -> bool:
	return world != null and world.cooking != null and world.tool_upgrades != null and world.tool_upgrades.profile_ready

func _refresh() -> void:
	if not is_open or world == null:
		return
	world.cooking.advance(world.farming.time_manager.now(), false)
	var model: ChefCooking = world.cooking
	var amount: int = int(quantity.value)
	var lines: PackedStringArray = []
	lines.append(tr(selected.display_name))
	for i: int in range(selected.ingredients.size()):
		var item: ItemDefinition = selected.ingredients[i]
		lines.append("%s: %d / %d" % [tr(item.display_name) + " (" + ItemQuality.label(selected.tier_at(i)) + ")", customer.selection.inventory.count_item(item.item_id, selected.tier_at(i)), selected.amounts[i] * amount])
	lines.append(tr("Cooking time: {seconds} seconds").format({"seconds": int(selected.cook_seconds)}))
	lines.append(tr("Ingredients are consumed when queued. Queued dishes cannot be cancelled."))
	details.text = "\n".join(lines)
	var summary_lines: PackedStringArray = [tr("Queued: %d · Ready: %d · Capacity: 20") % [model.queue.size(), model.ready.size()]]
	if not model.queue.is_empty():
		var left: int = maxi(0, int(ceil(float(model.queue[0].finish_at) - model.updated_at)))
		summary_lines.append(tr("Cooking: %s · %02d:%02d:%02d") % [tr(ChefCooking.find(model.queue[0].recipe).display_name), int(left / 3600.0), int((left % 3600) / 60.0), left % 60])
	var ready_counts: Dictionary = {}
	for id: String in model.ready:
		ready_counts[id] = int(ready_counts.get(id, 0)) + 1
	for id: String in ready_counts:
		summary_lines.append("%s × %d" % [tr(ChefCooking.find(id).display_name), ready_counts[id]])
	summary.text = "\n".join(summary_lines)
	var error: String = model.quote(String(selected.recipe_id), amount, customer.selection.inventory) if _available() else "Load your farm before cooking."
	cook_button.disabled = not error.is_empty()
	collect_button.disabled = not _available() or model.ready.is_empty() or model.busy
	status.text = tr(_message) if not _message.is_empty() else tr(error)
	for i: int in range(recipe_buttons.size()):
		recipe_buttons[i].set_pressed_no_signal(ChefCooking.RECIPES[i] == selected)

func _cook() -> void:
	if not _available():
		return
	_message = world.cooking.start(String(selected.recipe_id), int(quantity.value), customer.selection.inventory, world.farming.time_manager.now())
	if _message.is_empty():
		_message = "Chef is cooking. Come back later!"
		bought_this_visit = true
		_save.call_deferred()
	_refresh()

func _collect() -> void:
	if not _available():
		return
	var collected: int = world.cooking.collect(customer.selection.inventory, world.farming.time_manager.now())
	_message = "Dishes collected." if collected > 0 else "Your bag is full. Make room and collect again."
	if collected > 0:
		_save.call_deferred()
	_refresh()

func _save() -> void:
	var manager: GameSaveManager = get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

func _process(delta: float) -> void:
	if not is_open:
		return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		_refresh()
