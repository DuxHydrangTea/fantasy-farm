class_name CookingMenu
extends TradeMenu
## Scene-authored kitchen; commands continue to use the farm's serial queue.
var world: FarmWorld
@onready var panel: PanelContainer = %Panel
@onready var summary: Label = %Summary
@onready var details: Label = %Details
@onready var status: Label = %Status
@onready var cook_button: Button = %CookButton
@onready var collect_button: Button = %CollectButton
@onready var quantity: SpinBox = %Quantity
@onready var browse: ScrollContainer = %Browse
@onready var ingredient_list: VBoxContainer = %Ingredients
@onready var product_icon: TextureRect = %ProductIcon
@onready var product_name: Label = %ProductName
@onready var progress: ProgressBar = %CookingProgress
var recipe_buttons: Array[Button] = []
var selected: CookingRecipe = ChefCooking.RECIPES[0]
var _ingredient_counts: Array[Label] = []
var _elapsed: float = 0.0
var _message: String = ""
var _cookable_only: bool = false
var _compact: bool = false
var _refreshing: bool = false
const PRICE_CATALOG: ProducePriceCatalog = preload("res://resources/shops/produce_prices.tres")

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	_build_recipes()
	_build_ingredients()
	TouchQuantityComponent.attach(quantity, root, true)
	visit_started.connect(_visit)
	models_changed.connect(_refresh)
	root.resized.connect(_fit)
	quantity.value_changed.connect(_quantity_changed)
	cook_button.pressed.connect(_cook)
	collect_button.pressed.connect(_collect)
	(%Maximum as Button).pressed.connect(_set_maximum)
	(%AllRecipes as Button).pressed.connect(_filter.bind(false))
	(%CookableRecipes as Button).pressed.connect(_filter.bind(true))
	_fit()

func _build_recipes() -> void:
	for recipe: CookingRecipe in ChefCooking.RECIPES:
		var button: Button = Button.new()
		button.text = tr(recipe.display_name)
		button.tooltip_text = tr(recipe.display_name)
		button.icon = recipe.output.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.toggle_mode = true
		button.add_theme_stylebox_override("pressed", preload("res://resources/ui/cozy_hud/cooking_selected.tres"))
		button.pressed.connect(_select.bind(recipe))
		(%RecipeList as VBoxContainer).add_child(button)
		recipe_buttons.append(button)

func _build_ingredients() -> void:
	for child: Node in ingredient_list.get_children():
		child.free()
	_ingredient_counts.clear()
	for i: int in range(selected.ingredients.size()):
		var item: ItemDefinition = selected.ingredients[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		ingredient_list.add_child(row)
		var icon: TextureRect = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var caption: Label = Label.new()
		caption.text = tr(item.display_name)
		if not item.star_fruit:
			caption.text += " · " + ItemQuality.label(selected.tier_at(i))
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.add_theme_font_size_override("font_size", 16)
		row.add_child(caption)
		var count: Label = Label.new()
		count.add_theme_font_size_override("font_size", 16)
		row.add_child(count)
		_ingredient_counts.append(count)

func _fit() -> void:
	var compact: bool = root.size.x < 900 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	if compact != _compact:
		_compact = compact
		var content: VBoxContainer = %DetailContent
		content.reparent(%ActionContent if _compact else %DetailScroll)
		if _compact:
			content.get_parent().move_child(content, 0)
	(%DetailPanel as PanelContainer).visible = not _compact
	panel.custom_minimum_size = Vector2(minf(1140, maxf(0, root.size.x - 24)), minf(620, maxf(0, root.size.y - 16)))
	(%BrowsePanel as PanelContainer).custom_minimum_size.x = 180 if _compact else 240
	(%ActionColumn as VBoxContainer).custom_minimum_size.x = 0 if _compact else 280
	(%Body as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 12)
	(%Heading as Label).add_theme_font_size_override("font_size", 20 if _compact else 26)
	(%Balance as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%Hint as Label).visible = not _compact
	(%ProductIcon as TextureRect).custom_minimum_size.y = 48 if _compact else 112
	(%ProductName as Label).add_theme_font_size_override("font_size", 18 if _compact else 24)
	(%ActionHeading as Label).visible = not _compact
	for button: Button in recipe_buttons:
		button.custom_minimum_size.y = 48 if _compact else 64
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	for button: Button in [%AllRecipes, %CookableRecipes, cook_button, collect_button]:
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)

func _visit() -> void:
	world = customer.get_parent() as FarmWorld
	_message = ""
	quantity.value = 1
	browse.scroll_vertical = 0
	(%ActionScroll as ScrollContainer).scroll_vertical = 0
	_filter(false)
	close_button.grab_focus()

func _select(recipe: CookingRecipe) -> void:
	selected = recipe
	_message = ""
	quantity.set_value_no_signal(1)
	quantity.get_line_edit().text = "1"
	TouchQuantityComponent.refresh_for(quantity)
	_build_ingredients()
	_refresh()

func _filter(cookable: bool) -> void:
	_cookable_only = cookable
	(%AllRecipes as Button).set_pressed_no_signal(not cookable)
	(%CookableRecipes as Button).set_pressed_no_signal(cookable)
	if cookable and _maximum_for(selected) == 0:
		for recipe: CookingRecipe in ChefCooking.RECIPES:
			if _maximum_for(recipe) > 0:
				_select(recipe)
				break
	_refresh()

func _available() -> bool:
	return world != null and world.cooking != null and world.tool_upgrades != null and world.tool_upgrades.profile_ready

func _maximum_for(recipe: CookingRecipe) -> int:
	if not _available():
		return 0
	for amount: int in range(ChefCooking.CAPACITY, 0, -1):
		if world.cooking.quote(String(recipe.recipe_id), amount, customer.selection.inventory, customer.wallet).is_empty():
			return amount
	return 0

func _set_maximum() -> void:
	quantity.value = maxi(1, _maximum_for(selected))

func _quantity_changed(_value: float) -> void:
	quantity.get_line_edit().text = str(int(quantity.value))
	_message = ""
	_refresh()

func _duration(seconds: float) -> String:
	var value: int = maxi(0, int(ceil(seconds)))
	return "%02d:%02d:%02d" % [int(value / 3600.0), int((value % 3600) / 60.0), value % 60]

func _refresh() -> void:
	if not is_open or world == null or _refreshing:
		return
	_refreshing = true
	world.cooking.advance(world.farming.time_manager.now(), false)
	var amount: int = int(quantity.value)
	product_icon.texture = selected.output.icon
	product_name.text = tr(selected.display_name)
	(%Balance as Label).text = tr("{coins} coins").format({"coins": GameText.grouped_integer(customer.wallet.balance)})
	for i: int in range(_ingredient_counts.size()):
		var owned: int = customer.selection.inventory.count_item(selected.ingredients[i].item_id, selected.tier_at(i))
		var needed: int = selected.amounts[i] * amount
		_ingredient_counts[i].text = "%d / %d" % [owned, needed]
		_ingredient_counts[i].add_theme_color_override("font_color", Color("46643b") if owned >= needed else Color("a34029"))
	(%Output as Label).text = "%s × %d" % [tr(selected.output.display_name), amount]
	(%Cost as Label).text = tr("Coin cost: {coins}").format({"coins": GameText.grouped_integer(selected.coin_cost * amount)})
	(%Duration as Label).text = tr("Batch time: {time}").format({"time": _duration(selected.cook_seconds * amount)})
	details.text = _economy_text(amount)
	_refresh_queue()
	var error: String = world.cooking.quote(String(selected.recipe_id), amount, customer.selection.inventory, customer.wallet) if _available() else "Load your farm before cooking."
	cook_button.disabled = not error.is_empty()
	collect_button.disabled = not _available() or world.cooking.ready.is_empty() or world.cooking.busy
	collect_button.text = tr("Collect ready dishes") + " (%d)" % world.cooking.ready.size()
	(%Maximum as Button).disabled = _maximum_for(selected) == 0
	status.text = tr(_message) if not _message.is_empty() else tr(error)
	status.visible = not status.text.is_empty()
	var visible_count: int = 0
	for i: int in range(recipe_buttons.size()):
		var recipe: CookingRecipe = ChefCooking.RECIPES[i]
		var button: Button = recipe_buttons[i]
		button.visible = not _cookable_only or _maximum_for(recipe) > 0
		button.set_pressed_no_signal(recipe == selected)
		visible_count += int(button.visible)
	(%EmptyRecipes as Label).visible = visible_count == 0
	_refreshing = false

func _economy_text(amount: int) -> String:
	var output_price: ProducePrice = PRICE_CATALOG.find(selected.output.item_id)
	var inputs_value: int = selected.coin_cost * amount
	var marketable: bool = output_price != null
	for i: int in range(selected.ingredients.size()):
		var price: ProducePrice = PRICE_CATALOG.find(selected.ingredients[i].item_id)
		if price == null:
			marketable = false
		else:
			inputs_value += ItemQuality.unit_price(price.price, selected.tier_at(i)) * selected.amounts[i] * amount
	var text: String = tr("Ingredients are consumed when queued. Queued dishes cannot be cancelled.")
	if marketable:
		text = tr("Sale value: {sale} coins · Margin over ingredient sales: {margin} coins").format({"sale": output_price.price * amount, "margin": output_price.price * amount - inputs_value}) + "\n" + text
	return text

func _refresh_queue() -> void:
	var model: ChefCooking = world.cooking
	var lines: PackedStringArray = [tr("Kitchen capacity: {used}/{capacity}").format({"used": model.queue.size() + model.ready.size(), "capacity": ChefCooking.CAPACITY})]
	lines.append(tr("Queued: {queued} · Ready: {ready}").format({"queued": model.queue.size(), "ready": model.ready.size()}))
	progress.visible = not model.queue.is_empty()
	if not model.queue.is_empty():
		var recipe: CookingRecipe = ChefCooking.find(model.queue[0].recipe)
		var left: float = maxf(0, float(model.queue[0].finish_at) - model.updated_at)
		lines.append(tr("Cooking: {recipe}").format({"recipe": tr(recipe.display_name)}))
		lines.append(tr("Remaining: {time}").format({"time": _duration(left)}))
		progress.value = clampf(1.0 - left / recipe.cook_seconds, 0.0, 1.0) * 100.0
	else:
		lines.append(tr("Kitchen is idle."))
	summary.text = "\n".join(lines)
	var counts: Dictionary = {}
	for id: String in model.ready:
		counts[id] = int(counts.get(id, 0)) + 1
	var ready_lines: PackedStringArray = []
	for id: String in counts:
		ready_lines.append("%s × %d" % [tr(ChefCooking.find(id).display_name), counts[id]])
	(%ReadyDishes as Label).text = "\n".join(ready_lines)
	(%ReadyDishes as Label).visible = not ready_lines.is_empty()
func _cook() -> void:
	quantity.apply()
	if not _available():
		return
	_message = world.cooking.start(String(selected.recipe_id), int(quantity.value), customer.selection.inventory, world.farming.time_manager.now(), customer.wallet)
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for i: int in range(recipe_buttons.size()):
			recipe_buttons[i].text = tr(ChefCooking.RECIPES[i].display_name)
			recipe_buttons[i].tooltip_text = recipe_buttons[i].text
		_build_ingredients()
		_refresh()
