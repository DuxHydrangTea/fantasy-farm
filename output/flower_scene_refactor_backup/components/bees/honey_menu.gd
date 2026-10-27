class_name HoneyMenu
extends TradeMenu
## Shared bee journal, batch collection and repairs; scrollable on touch screens.
var world: FarmWorld
var hive: Beehive
var panel: PanelContainer
var title: Label
var summary: Label
var repair_button: Button
var harvest_button: Button
var status: Label
var browse: ScrollContainer
var content: VBoxContainer
var recipe_rows: Array[HBoxContainer] = []
var _elapsed: float = 0.0
var _message: String = ""

func _ready() -> void:
	layer = 25
	_build()
	super._ready()
	models_changed.connect(_refresh)
	world.honey_garden.changed.connect(_refresh)
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
	close_button.text = "X"
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
	repair_button = _button(content, _repair)
	for id: String in HoneyComboCatalog.IDS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		content.add_child(row)
		var icon: TextureRect = TextureRect.new()
		icon.texture = HoneyComboCatalog.item(id).icon
		icon.custom_minimum_size = Vector2(48,48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		_label(row)
		recipe_rows.append(row)
	status = _label(content)
	harvest_button = _button(body, _collect)

func open_hive(target: Beehive) -> bool:
	if not world.honey_garden.access_error(target).is_empty():
		return false
	hive = target
	_message = ""
	if not super.open(null,world.player):
		return false
	_fit()
	_refresh()
	browse.scroll_vertical = 0
	return true

func _fit() -> void:
	panel.size = Vector2(minf(760,root.size.x-24),minf(650,root.size.y-24))
	panel.position = (root.size-panel.size)*0.5

func _refresh() -> void:
	if not is_open or not is_instance_valid(hive):
		return
	title.text = tr("Bee journal")
	var production: BeehiveProductionComponent = hive.production
	summary.text = tr("Eight neighboring pots per hive. Hybrids have priority over mono flowers.")
	summary.text += "\n" + tr("A hybrid needs two matching flowers opposite each other for each species.")
	summary.text += "\n" + tr("Recipe locks when a batch starts. Changing flowers affects the next batch.")
	summary.text += "\n" + tr("Garden wind: honey speed +25%. Field wind: radius +50%. Rain: base speed.")
	summary.text += "\n" + tr("Field hives keep their flower-radius rules and crop growth bonus.")
	summary.text += "\n" + tr("Honey: {percent}%").format({"percent":floori(production.work/hive.definition.cycle_seconds*100)})
	if production.ready_item != null:
		summary.text += " · " + tr(production.ready_item.display_name) + " ×%d" % production.batch_amount()
	elif not production.batch_recipe.is_empty():
		summary.text += " · " + tr(HoneyComboCatalog.item(production.batch_recipe).display_name)
	elif hive.garden_slot >= 0:
		summary.text += " · " + tr("Next batch") + ": " + tr(HoneyComboCatalog.item(world.honey_garden.recipe_for(hive,world.apiary._flowers(),world.apiary.last_at)).display_name)
	for i: int in range(HoneyComboCatalog.IDS.size()):
		var id: String = HoneyComboCatalog.IDS[i]
		var row: HBoxContainer = recipe_rows[i]
		(row.get_child(0) as TextureRect).modulate = Color.WHITE if id in world.honey_garden.discoveries else Color(0,0,0,1)
		(row.get_child(1) as Label).text = tr(HoneyComboCatalog.item(id).display_name) + "\n" + HoneyComboCatalog.instruction(id)
		(row.get_child(1) as Label).text += "\n" + (tr("Cooked at Chef") if id in world.honey_garden.discoveries else tr("Cook its custard at Chef to reveal the jar."))
	repair_button.text = tr("Repair: 15 wood + 500 coins")
	repair_button.visible = hive.garden_slot >= 0 and not hive.repaired
	repair_button.disabled = world.tool_upgrades.wood_owned() < 15 or world.player.wallet.balance < 500
	harvest_button.text = tr("Collect honey")
	harvest_button.disabled = production.ready_item == null or world.player.selection.inventory.capacity_for(production.ready_item) < production.batch_amount()
	status.text = tr(_message) if not _message.is_empty() else tr(world.honey_garden.notice)

func _repair() -> void:
	_message = world.honey_garden.repair(hive)
	if _message.is_empty():
		_message = "Hive repaired."
		_save.call_deferred()
	_refresh()

func _collect() -> void:
	_message = world.honey_garden.collect(hive)
	if _message.is_empty():
		_message = "Honey collected."
		_save.call_deferred()
	_refresh()

func _save() -> void:
	var manager: GameSaveManager = get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

func _process(delta: float) -> void:
	if not is_open:
		return
	if not is_instance_valid(hive) or world.player.global_position.distance_to(hive.global_position) > 32:
		close(false)
		return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		world.apiary.sync()
		_refresh()
