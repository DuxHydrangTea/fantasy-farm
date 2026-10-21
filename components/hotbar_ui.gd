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
var buttons: Array[InventorySlot] = []

func _ready() -> void:
	var player: FarmPlayer = get_parent() as FarmPlayer
	boosters = player.boosters if player != null else null
	interactions = player.interactions if player != null else null
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
		button.slot_index = index
		button.show_shortcut = true
		button.pressed.connect(_select_slot.bind(index))
		slots.add_child(button)
		buttons.append(button)
	selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(selection.selected_index, &"")

func _select_slot(index: int) -> void:
	selection.select_slot(index)
	_on_selection_changed(selection.selected_index, &"")

func _on_selection_changed(index: int, _tool: StringName) -> void:
	for i: int in range(buttons.size()):
		buttons[i].set_selected(i == index)
	selected_name.text = selection.get_selected_name()

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
	hint.visible = root.size.x >= 1000.0 and root.size.y >= 700.0

func _process(_delta: float) -> void:
	if boosters == null:
		return
	# Reuse the existing hotbar text line so feedback never covers animal details.
	var feedback: String = interactions.feedback_source() if interactions != null else ""
	if feedback.is_empty():
		var player: FarmPlayer = get_parent() as FarmPlayer
		feedback = player.hive_placement.feedback_source() if player != null and player.hive_placement != null else ""
	if feedback.is_empty():
		feedback = boosters.feedback_source()
	var text: String = tr(feedback) if not feedback.is_empty() else selection.get_selected_name()
	if selected_name.text != text:
		selected_name.text = text
	var item: ItemDefinition = boosters.selected_booster()
	if not feedback.is_empty():
		selected_name.tooltip_text = tr(feedback)
	elif item != null:
		var instruction: String = "Face a crop and right-click / Space to fertilize." if item.booster_kind == ItemDefinition.BoosterKind.FERTILIZER else "Face an animal and right-click / Space to give tonic."
		selected_name.tooltip_text = tr(item.description) + "\n" + tr(instruction)
	else:
		selected_name.tooltip_text = ""
