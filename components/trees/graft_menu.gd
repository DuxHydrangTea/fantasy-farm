class_name GraftMenu
extends TradeMenu
## Compare future crops, review a revision-bound quote, then confirm explicitly.
var world: FarmWorld
var tree: FruitTree
@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var summary: Label = %Summary
@onready var yield_button: Button = %YieldButton
@onready var quality_button: Button = %QualityButton
@onready var harvest_button: Button = %Harvest
@onready var confirm_button: Button = %Confirm
@onready var status: Label = %Status
@onready var browse: ScrollContainer = %Browse
@onready var content: VBoxContainer = %Content
var _revision: int = -1
var _elapsed: float = 0.0
var _message: String = ""
var _selected_direction: int = FruitTree.Graft.NONE
var _review_revision: int = -1
var _offer: Dictionary = {}
var _compact: bool = false
var _selected_style: StyleBoxFlat
var _texture_cache: Dictionary = {}

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	models_changed.connect(_refresh)
	world.grafting.changed.connect(_refresh)
	root.resized.connect(_fit)
	yield_button.pressed.connect(_select_direction.bind(FruitTree.Graft.YIELD))
	quality_button.pressed.connect(_select_direction.bind(FruitTree.Graft.QUALITY))
	confirm_button.pressed.connect(_confirm_choice)
	harvest_button.pressed.connect(_collect)
	(%WaxIcon as TextureRect).texture = preload("res://items/boosters/grafting_wax.tres").icon
	_selected_style = root.theme.get_stylebox("panel", "DetailCard").duplicate() as StyleBoxFlat
	_selected_style.bg_color = Color("d6dfb8")
	_fit()

func _cropped(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if _texture_cache.has(texture):
		return _texture_cache[texture] as Texture2D
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return texture
	var region: Rect2i = source.get_used_rect()
	if not region.has_area():
		return texture
	var cropped: AtlasTexture = AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(region)
	_texture_cache[texture] = cropped
	return cropped

func open_tree(target: FruitTree) -> bool:
	if is_open:
		return false
	world.workers.settle(world.farming.time_manager.now())
	if not world.grafting.access_error(target).is_empty():
		return false
	tree = target
	_message = ""
	_clear_review()
	if not super.open(null, world.player):
		return false
	_refresh()
	browse.scroll_vertical = 0
	(%CurrentScroll as ScrollContainer).scroll_vertical = 0
	(%ReviewScroll as ScrollContainer).scroll_vertical = 0
	close_button.grab_focus()
	return true

func _fit() -> void:
	var compact: bool = root.size.x < 900 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	if compact != _compact:
		_compact = compact
		(%ReviewContent as VBoxContainer).reparent(%Content if compact else %ReviewScroll)
		confirm_button.reparent(%ChoiceBody if compact else %ReviewBody)
	(%ReviewPanel as PanelContainer).visible = not _compact
	panel.custom_minimum_size = Vector2(minf(1120, maxf(0, root.size.x - 24)), minf(640, maxf(0, root.size.y - 16)))
	(%Body as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 12)
	(%CurrentPanel as PanelContainer).custom_minimum_size.x = 168 if _compact else 240
	(%ReviewPanel as PanelContainer).custom_minimum_size.x = 0 if _compact else 280
	(%TreeIcon as TextureRect).custom_minimum_size.y = 48 if _compact else 160
	(%CurrentIcon as TextureRect).visible = not _compact
	(%CurrentContent as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 8)
	for label: Label in [%Active, %CurrentHeading, %ProgressText]:
		label.add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%Hint as Label).visible = not _compact
	(%ReviewHeading as Label).visible = not _compact
	(%FutureIcon as TextureRect).visible = _selected_direction != FruitTree.Graft.NONE and not _compact
	(%ReviewContent as VBoxContainer).add_theme_constant_override("separation", 6 if _compact else 12)
	(%Cost as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%WaxCount as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%SelectedDirection as Label).add_theme_font_size_override("font_size", 16 if _compact else 18)
	title.add_theme_font_size_override("font_size", 20 if _compact else 26)
	(%Balance as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%TreeName as Label).add_theme_font_size_override("font_size", 16 if _compact else 22)
	for label: Label in [%YieldHeading, %QualityHeading, %YieldOutput, %QualityOutput, %FutureCrop, %CurrentCrop]:
		label.add_theme_font_size_override("font_size", 16 if _compact else 20)
	for button: Button in [yield_button, quality_button, harvest_button, confirm_button]:
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)

func _clear_review() -> void:
	_selected_direction = FruitTree.Graft.NONE
	_review_revision = -1
	_offer = {}

func _select_direction(direction: int) -> void:
	if not is_open or not is_instance_valid(tree) or tree.removed:
		return
	_selected_direction = direction
	_review_revision = tree.graft_revision
	_offer = world.grafting.quote(tree, direction).duplicate(true)
	_message = ""
	_refresh()
	if _compact:
		_show_review.call_deferred()

func _show_review() -> void:
	if is_open and _compact:
		browse.scroll_vertical = roundi((%ReviewContent as VBoxContainer).position.y)

func _future_item(direction: int) -> ItemDefinition:
	return tree.definition.star_harvest_item if direction == FruitTree.Graft.QUALITY else tree.definition.harvest_item

func _future_amount(direction: int) -> int:
	return tree.definition.harvest_amount * (2 if direction == FruitTree.Graft.YIELD else 1)

func _output_text(direction: int) -> String:
	var item: ItemDefinition = _future_item(direction)
	return "%s × %s" % [tr(item.display_name), GameText.grouped_integer(_future_amount(direction))] if item != null else tr("Unavailable")

func _refresh() -> void:
	if not is_open or not is_instance_valid(tree) or tree.removed:
		return
	_revision = tree.graft_revision
	title.text = tr("Fruit tree grafting")
	(%TreeName as Label).text = tr(tree.definition.display_name)
	(%TreeIcon as TextureRect).texture = _cropped(tree.sprite.texture)
	(%Active as Label).text = FruitTree.graft_name(tree.active_graft)
	(%CurrentIcon as TextureRect).texture = _cropped(tree.harvest_item().icon)
	(%CurrentCrop as Label).text = "%s × %s" % [tr(tree.harvest_item().display_name), GameText.grouped_integer(tree.harvest_amount())]
	var progress: int = roundi(clampf(tree.fruit_work / tree.definition.fruit_cycle_seconds, 0, 1) * 100)
	(%Progress as ProgressBar).value = progress
	(%ProgressText as Label).text = tr("Ready to harvest") if tree.has_fruit() else tr("Fruit progress: {percent}%").format({"percent": progress})
	(%Pending as Label).text = tr("Next crop: {direction}").format({"direction": FruitTree.graft_name(tree.pending_graft)}) if tree.pending_graft != FruitTree.Graft.NONE else ""
	(%Pending as Label).visible = tree.pending_graft != FruitTree.Graft.NONE
	(%Balance as Label).text = tr("{coins} coins").format({"coins": GameText.grouped_integer(customer.wallet.balance)})
	(%YieldIcon as TextureRect).texture = _cropped(tree.definition.harvest_item.icon)
	(%QualityIcon as TextureRect).texture = _cropped(tree.definition.star_harvest_item.icon) if tree.definition.star_harvest_item != null else null
	(%YieldOutput as Label).text = _output_text(FruitTree.Graft.YIELD)
	(%QualityOutput as Label).text = _output_text(FruitTree.Graft.QUALITY)
	(%YieldDemand as Label).text = tr("Requested by {count} current orders").format({"count": world.grafting.order_demand(tree)})
	(%QualityDemand as Label).text = tr("Used in {count} Chef recipes").format({"count": world.grafting.kitchen_demand(tree)})
	var yield_quote: Dictionary = world.grafting.quote(tree, FruitTree.Graft.YIELD)
	var quality_quote: Dictionary = world.grafting.quote(tree, FruitTree.Graft.QUALITY)
	_refresh_choice(yield_button, %YieldCard, FruitTree.Graft.YIELD, yield_quote)
	_refresh_choice(quality_button, %QualityCard, FruitTree.Graft.QUALITY, quality_quote)
	var cost: int = 0 if tree.active_graft == FruitTree.Graft.NONE and tree.pending_graft == FruitTree.Graft.NONE else 1
	(%Cost as Label).text = tr("First choice is free") if cost == 0 else tr("Change direction: 1 Grafting Wax")
	(%WaxCount as Label).text = tr("Grafting Wax in bag: {count}").format({"count": customer.selection.inventory.count_item(GraftService.WAX)})
	_refresh_review()
	var can_hold: bool = customer.selection.inventory.capacity_for(tree.harvest_item()) >= tree.harvest_amount()
	harvest_button.disabled = not tree.has_fruit() or not can_hold or not world.grafting.access_error(tree).is_empty()
	status.text = tr(_message) if not _message.is_empty() else ""
	if _selected_direction != FruitTree.Graft.NONE:
		var latest: Dictionary = world.grafting.quote(tree, _selected_direction)
		if tree.graft_revision != _review_revision:
			status.text = tr("The tree changed. Select a direction again to review its new cost.")
		elif not latest.ok:
			status.text = tr(str(latest.get("error", "")))
			if str(latest.get("error", "")) == "Not enough Grafting Wax in your bag.":
				status.text += "\n" + tr("To change direction, craft Grafting Wax at Chef (5 wood, 1 Wild Honey, 1,000 coins).")
	if tree.has_fruit() and not can_hold:
		status.text = tr("Your bag cannot hold the whole crop. Free space first.")
	status.visible = not status.text.is_empty()
	summary.text = tr("Current direction: {direction}").format({"direction": FruitTree.graft_name(tree.active_graft)}) + "\n" + tr("Current crop: {item} × {count}").format({"item": tr(tree.harvest_item().display_name), "count": tree.harvest_amount()})

func _refresh_choice(button: Button, card: PanelContainer, direction: int, quote: Dictionary) -> void:
	var error: String = str(quote.get("error", ""))
	# A missing-wax choice remains reviewable, but the confirm action stays disabled.
	button.disabled = not quote.ok and error != "Not enough Grafting Wax in your bag."
	button.tooltip_text = tr(error)
	button.set_pressed_no_signal(_selected_direction == direction)
	if error == "This graft direction is already selected.":
		button.text = tr("Selected for the next crop") if tree.pending_graft != FruitTree.Graft.NONE else tr("Current direction")
	else:
		button.text = tr("Reviewing this direction") if _selected_direction == direction else tr("Review this direction")
	var planned: int = tree.pending_graft if tree.pending_graft != FruitTree.Graft.NONE else tree.active_graft
	var highlighted: bool = direction == (_selected_direction if _selected_direction != FruitTree.Graft.NONE else planned)
	if highlighted:
		card.add_theme_stylebox_override("panel", _selected_style)
	else:
		card.remove_theme_stylebox_override("panel")

func _refresh_review() -> void:
	var selected: bool = _selected_direction != FruitTree.Graft.NONE
	(%SelectedDirection as Label).text = FruitTree.graft_name(_selected_direction) if selected else tr("Choose a graft direction to review.")
	(%FutureIcon as TextureRect).texture = _cropped(_future_item(_selected_direction).icon) if selected and _future_item(_selected_direction) != null else null
	(%FutureIcon as TextureRect).visible = selected and not _compact
	(%FutureCrop as Label).text = tr("Next crop output: {output}").format({"output": _output_text(_selected_direction)}) if selected else ""
	confirm_button.disabled = true
	if selected:
		var latest: Dictionary = world.grafting.quote(tree, _selected_direction)
		confirm_button.disabled = not latest.ok or tree.graft_revision != _review_revision or int(latest.get("wax", -1)) != int(_offer.get("wax", -2))

func _confirm_choice() -> void:
	if not is_open or not is_instance_valid(tree) or tree.removed or _selected_direction == FruitTree.Graft.NONE:
		return
	if tree.graft_revision != _review_revision:
		_message = "The tree changed. Select a direction again to review its new cost."
		_refresh()
		return
	_choose(_selected_direction, _review_revision)

func _choose(direction: int, expected_revision: int = -1) -> void:
	if not is_instance_valid(tree) or tree.removed:
		close(false)
		return
	_message = world.grafting.choose(tree, direction, _revision if expected_revision < 0 else expected_revision)
	if _message.is_empty():
		_message = "Graft scheduled for the next crop."
		_clear_review()
		_save.call_deferred()
	_refresh()

func _collect() -> void:
	if not is_instance_valid(tree) or tree.removed:
		close(false)
		return
	_message = world.grafting.collect(tree)
	if _message.is_empty():
		_message = "Fruit harvested."
		_clear_review()
		_save.call_deferred()
	_refresh()

func _save() -> void:
	var manager: GameSaveManager = get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

func _process(delta: float) -> void:
	if not is_open:
		return
	if not is_instance_valid(tree) or tree.removed or world.player.global_position.distance_to(tree.global_position) > 32:
		close(false)
		return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
