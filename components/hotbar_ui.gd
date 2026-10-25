class_name HotbarUI
extends CanvasLayer

const SLOT_ACTIONS: Array[StringName] = [&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5", &"hotbar_6"]

@export var root: Control
@export var hint: Label
@export var selection: ToolSelectionComponent
@export var slots: HBoxContainer
@export var selected_name: Label
var interactions: PlayerInteractionComponent
var boosters: BoosterInteractionComponent
var placement: BeehivePlacementComponent
var buttons: Array[InventorySlot] = []
var _feedback_deadline: int = 0
var inventory_button: Button

func _ready() -> void:
	var player: FarmPlayer = get_parent() as FarmPlayer
	boosters = player.boosters if player != null else null
	interactions = player.interactions if player != null else null
	placement = player.hive_placement if player != null else null
	set_process(false)
	selected_name.clip_text = true
	selected_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UIScaleComponent.attach(self, root)
	root.resized.connect(_fit_layout)
	_fit_layout()
	assert(selection != null, "Hotbar requires ToolSelection")
	for index: int in range(selection.HOTBAR_SIZE):
		var button: InventorySlot = InventorySlot.new()
		button.name = "Slot" + str(index)
		button.inventory = selection.inventory
		button.hotbar_skin = true
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.slot_index = index
		button.show_shortcut = true
		button.pressed.connect(_select_slot.bind(index))
		slots.add_child(button)
		buttons.append(button)
	inventory_button = Button.new()
	inventory_button.name = "OpenInventory"
	inventory_button.custom_minimum_size = Vector2(92, 68)
	inventory_button.add_theme_font_size_override("font_size", 18)
	inventory_button.focus_mode = Control.FOCUS_NONE
	inventory_button.pressed.connect(_open_inventory)
	slots.add_child(inventory_button)
	selection.inventory_visibility_changed.connect(_menu_changed)
	selection.shop_visibility_changed.connect(_menu_changed)
	selection.objectives_visibility_changed.connect(_menu_changed)
	selection.selection_changed.connect(_on_selection_changed)
	_fit_layout()
	for source: Node in [interactions, placement, boosters]:
		if source != null:
			source.connect("feedback_changed", _refresh_feedback)
	_on_selection_changed(selection.selected_index, &"")

func _select_slot(index: int) -> void:
	selection.select_slot(index)
	_on_selection_changed(selection.selected_index, &"")

func _open_inventory() -> void:
	selection.set_inventory_open(true)

func _menu_changed(_open: bool) -> void:
	root.visible = not selection.is_menu_open()

func _on_selection_changed(index: int, _tool: StringName) -> void:
	for i: int in range(buttons.size()):
		buttons[i].set_selected(i == index and selection.storage_seed_id.is_empty())
	_refresh_feedback()
	_refresh_controls()

func _refresh_controls() -> void:
	if inventory_button == null:
		return
	inventory_button.text = tr("Bag") if MobileLayout.is_touch(get_viewport()) else tr("Bag") + "\n[" + GameText.action_key(&"toggle_inventory") + "]"
	inventory_button.tooltip_text = tr("Open inventory")
	var instructions: Dictionary = {
		&"tool": "Space / Right-click: till soil",
		&"water": "Space / Right-click: water",
		&"plant": "Space / Right-click: plant",
		&"fertilize": "Space / Right-click: fertilize",
		&"animal_tonic": "Space / Right-click: give tonic",
		&"place_beehive": "Space / Right-click: place hive",
	}
	hint.text = tr(String(instructions.get(selection.get_selected_action(), "Select a tool to use it")))

func _unhandled_input(event: InputEvent) -> void:
	if selection.is_menu_open():
		return
	if event is InputEventKey:
		if not event.is_pressed() or event.is_echo():
			return
		for index: int in range(SLOT_ACTIONS.size()):
			if event.is_action_pressed(SLOT_ACTIONS[index]):
				selection.select_slot(index)
				get_viewport().set_input_as_handled()
				return

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_on_selection_changed(selection.selected_index, &"")

func _fit_layout() -> void:
	var touch: bool = MobileLayout.is_touch(get_viewport())
	hint.visible = not touch and root.size.x >= 800.0 and root.size.y >= 500.0
	selected_name.add_theme_font_size_override("font_size", 20)
	hint.add_theme_font_size_override("font_size", 18)
	var bottom: MarginContainer = slots.get_parent().get_parent() as MarginContainer
	bottom.offset_top = -144
	bottom.offset_bottom = -16
	bottom.offset_left = 88 if touch else 0
	bottom.offset_right = -88 if touch else 0
	if touch:
		bottom.offset_top = -104
		bottom.offset_bottom = -8
	for button: InventorySlot in buttons:
		button.custom_minimum_size = Vector2(48, 48) if touch else Vector2(64, 64)
		button.refresh()
	if inventory_button != null:
		inventory_button.custom_minimum_size = Vector2(64, 48) if touch else Vector2(92, 64)
		inventory_button.clip_text = touch
		inventory_button.add_theme_font_size_override("font_size", 16 if touch else 18)
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			var style: StyleBoxTexture = StyleBoxTexture.new()
			style.texture = InventorySlot.HOTBAR_NORMAL if state in [&"normal",&"disabled"] else InventorySlot.HOTBAR_SELECTED
			for edge: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
				style.set_texture_margin(edge,4.0)
				style.set_content_margin(edge,3.0 if touch else 6.0)
			inventory_button.add_theme_stylebox_override(state,style)
		for state: String in ["font_color","font_hover_color","font_pressed_color"]:
			inventory_button.add_theme_color_override(state,Color(0.9,0.9,0.96))
		_refresh_controls()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _feedback_deadline:
		_refresh_feedback()

func _refresh_feedback() -> void:
	if boosters == null:
		selected_name.text = selection.get_selected_name()
		return
	# Reuse the existing hotbar text line so feedback never covers animal details.
	var feedback: String = interactions.feedback_source() if interactions != null else ""
	if feedback.is_empty():
		feedback = placement.feedback_source() if placement != null else ""
	if feedback.is_empty():
		feedback = boosters.feedback_source()
	var text: String = tr(feedback) if not feedback.is_empty() else selection.get_selected_name()
	if selected_name.text != text:
		selected_name.text = text
	var item: ItemDefinition = boosters.selected_booster()
	var tooltip: String = ""
	if not feedback.is_empty():
		tooltip = tr(feedback)
	elif item != null:
		var instruction: String = "Face a crop and right-click / Space to fertilize." if item.booster_kind != ItemDefinition.BoosterKind.ANIMAL_TONIC else "Face an animal and right-click / Space to give tonic."
		tooltip = tr(item.description) + "\n" + tr(instruction)
	if selected_name.tooltip_text != tooltip:
		selected_name.tooltip_text = tooltip
	# Only keep the inexpensive clock check alive while feedback can expire.
	_feedback_deadline = 0
	var now: int = Time.get_ticks_msec()
	for source: Node in [interactions, placement, boosters]:
		if source == null:
			continue
		var deadline: int = int(source.call("feedback_expires_at"))
		if deadline > now and (_feedback_deadline == 0 or deadline < _feedback_deadline):
			_feedback_deadline = deadline
	set_process(_feedback_deadline > 0)
