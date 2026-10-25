class_name GraftMenu
extends TradeMenu
## One shared tree menu, with choices and harvest inside the same touch modal.
var world: FarmWorld
var tree: FruitTree
var panel: PanelContainer
var title: Label
var summary: Label
var yield_button: Button
var quality_button: Button
var harvest_button: Button
var status: Label
var browse: ScrollContainer
var content: VBoxContainer
var _revision: int = -1
var _elapsed: float = 0.0
var _message: String = ""

func _ready() -> void:
	layer = 25
	_build()
	super._ready()
	models_changed.connect(_refresh)
	world.grafting.changed.connect(_refresh)
	root.resized.connect(_fit)

func _label(parent: Node) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label

func _button(parent: Node, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size.y = 64
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	button.pressed.connect(callback)
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
	root.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	title = _label(header)
	close_button = _button(header, func() -> void: pass)
	close_button.text = "×"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.custom_minimum_size = Vector2(64, 64)
	browse = ScrollContainer.new()
	browse.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browse.follow_focus = true
	body.add_child(browse)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	browse.add_child(content)
	summary = _label(content)
	yield_button = _button(content, _choose.bind(FruitTree.Graft.YIELD))
	quality_button = _button(content, _choose.bind(FruitTree.Graft.QUALITY))
	status = _label(content)
	harvest_button = _button(body, _collect)

func open_tree(target: FruitTree) -> bool:
	world.workers.settle(world.farming.time_manager.now())
	if not world.grafting.access_error(target).is_empty():
		return false
	tree = target
	_message = ""
	if not super.open(null, world.player):
		return false
	_fit()
	_refresh()
	browse.scroll_vertical = 0
	return true

func _fit() -> void:
	panel.size = Vector2(minf(720, root.size.x - 24), minf(620, root.size.y - 24))
	panel.position = (root.size - panel.size) * 0.5

func _refresh() -> void:
	if not is_open or not is_instance_valid(tree) or tree.removed:
		return
	_revision = tree.graft_revision
	title.text = tr("Fruit tree grafting") + " · " + tr(tree.definition.display_name)
	summary.text = tr("Current direction: {direction}").format({"direction": FruitTree.graft_name(tree.active_graft)})
	summary.text += "\n" + tr("Current crop: {item} × {count}").format({"item": tr(tree.harvest_item().display_name), "count": tree.harvest_amount()})
	summary.text += "\n" + tr("Fruit progress: {percent}%").format({"percent": roundi(100.0 * tree.fruit_work / tree.definition.fruit_cycle_seconds)})
	if tree.pending_graft != FruitTree.Graft.NONE:
		summary.text += "\n" + tr("Next crop: {direction}").format({"direction": FruitTree.graft_name(tree.pending_graft)})
	summary.text += "\n" + tr("Changes apply after the next harvest. The current crop stays unchanged.")
	summary.text += "\n" + tr("Grafting Wax in bag: {count}").format({"count": world.player.selection.inventory.count_item(GraftService.WAX)})
	var cost: String = tr("First choice is free") if tree.active_graft == FruitTree.Graft.NONE and tree.pending_graft == FruitTree.Graft.NONE else tr("Change direction: 1 Grafting Wax")
	yield_button.text = tr("Yield: double ordinary fruit") + "\n" + tr("Requested by {count} current orders").format({"count": world.grafting.order_demand(tree)}) + " · " + cost
	quality_button.text = tr("Selection: original amount of Star fruit") + "\n" + tr("Used in {count} Chef recipes").format({"count": world.grafting.kitchen_demand(tree)}) + " · " + cost
	var yield_quote: Dictionary = world.grafting.quote(tree, FruitTree.Graft.YIELD)
	var quality_quote: Dictionary = world.grafting.quote(tree, FruitTree.Graft.QUALITY)
	yield_button.disabled = not yield_quote.ok
	quality_button.disabled = not quality_quote.ok
	yield_button.tooltip_text = tr(yield_quote.get("error", ""))
	quality_button.tooltip_text = tr(quality_quote.get("error", ""))
	harvest_button.text = tr("Harvest current crop")
	var can_hold: bool = world.player.selection.inventory.capacity_for(tree.harvest_item()) >= tree.harvest_amount()
	harvest_button.disabled = not tree.has_fruit() or not can_hold or not world.grafting.access_error(tree).is_empty()
	status.text = tr(_message) if not _message.is_empty() else tr("You can leave this tree unspecialized. It keeps producing ordinary fruit.")
	if tree.has_fruit() and not can_hold:
		status.text = tr("Your bag cannot hold the whole crop. Free space first.")
		return
	if not _message.is_empty():
		return
	if not yield_quote.ok and not quality_quote.ok:
		status.text = tr("To change direction, craft Grafting Wax at Chef (5 wood, 1 Wild Honey, 1,000 coins).")

func _choose(direction: int) -> void:
	_message = world.grafting.choose(tree, direction, _revision)
	if _message.is_empty():
		_message = "Graft scheduled for the next crop."
		_save.call_deferred()
	_refresh()

func _collect() -> void:
	_message = world.grafting.collect(tree)
	if _message.is_empty():
		_message = "Fruit harvested."
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
