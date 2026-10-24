class_name TutorialHints
extends Node
## A brief optional preview; the full instruction is always available in Help.
var world: FarmWorld
var button: Button
var label: Label
var _timer: Timer
var _shown_id: String = ""
var _elapsed: float = 0

func _ready() -> void:
	button = Button.new()
	button.name = "TutorialHint"
	button.pressed.connect(world.help_ui.open_help)
	world.objective_ui.root.add_child(button)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 3
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	margin.add_child(label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 8
	_timer.timeout.connect(_seen)
	add_child(_timer)
	world.tutorial.changed.connect(refresh)
	world.objectives.progress.changed.connect(refresh)
	world.player.selection.inventory_visibility_changed.connect(_menu)
	world.player.selection.shop_visibility_changed.connect(_menu)
	world.player.selection.objectives_visibility_changed.connect(_menu)
	refresh()

func _menu(_open: bool) -> void:
	refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0
		refresh()

func refresh() -> void:
	if not is_inside_tree() or not _timer.is_inside_tree():
		return
	var goal: ObjectiveDefinition = world.objectives.progress.active()
	var id: String = String(goal.objective_id) if goal != null else ""
	var hud: HBoxContainer = world.objective_ui.hud
	button.position = hud.position + Vector2(0, hud.size.y + 4)
	button.size = Vector2(hud.size.x, 74)
	var free_bottom: float = world.objective_ui.root.size.y - 128
	var portrait: bool = MobileLayout.is_touch(get_viewport()) and world.objective_ui.root.size.y > world.objective_ui.root.size.x
	button.visible = not portrait and not id.is_empty() and world.tutorial.capture().enabled and not world.tutorial.seen(id) and not world.player.selection.is_menu_open() and button.position.y + button.size.y <= free_bottom
	if not button.visible:
		_timer.stop()
		_shown_id = ""
		return
	label.text = tr("Open Objectives to claim this reward and continue.") if world.objectives.progress.ready_to_claim() else tr(String(GuideContent.SHORT.get(id, "")))
	button.tooltip_text = tr("Help") + " [H]"
	if _shown_id != id:
		_shown_id = id
		_timer.start()

func _seen() -> void:
	if button.is_visible_in_tree():
		world.tutorial.mark_seen(_shown_id)
