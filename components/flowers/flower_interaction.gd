extends Node2D
## One locked target and one impact per action, sharing the player's tool states.
const Garden = preload("res://components/flowers/flower_garden.gd")
const Pot = preload("res://components/flowers/flower_pot.gd")
const Item = preload("res://scripts/item_definition.gd")
const Selection = preload("res://components/tool_selection_component.gd")
@export var selection: Selection
@export var animation: AnimationComponent
@export var state: StateComponent
@export var impact_frame: int = 3
var focused_pot: Pot
var _pending: Pot
var _action: StringName = &""
var _seed: Item
var _slot: int = -1
@onready var prompt: Label = $Prompt

func _ready() -> void:
	if selection == null:
		selection = get_parent().get_node("ToolSelection") as Selection
	if animation == null:
		animation = get_parent().get_node("AnimationComponent") as AnimationComponent
	if state == null:
		state = get_parent().get_node("StateComponent") as StateComponent
	state.state_changed.connect(_on_state_changed)
	animation.animated_sprite.frame_changed.connect(_on_frame_changed)
	prompt.hide()

func _physics_process(_delta: float) -> void:
	refresh()

func _reachable(pot: Pot) -> bool:
	return is_instance_valid(pot) and pot.global_position.distance_to((get_parent() as Node2D).global_position) <= 28.0

func refresh() -> void:
	if is_instance_valid(focused_pot):
		focused_pot.set_focused(false)
	focused_pot = null
	prompt.hide()
	if selection.inventory_open:
		return
	var point: Vector2 = (get_parent() as Node2D).global_position
	if not _action.is_empty() and _reachable(_pending):
		focused_pot = _pending
	else:
		for garden: Node in get_tree().get_nodes_in_group(&"flower_gardens"):
			var candidate: Pot = (garden as Garden).focused_pot(point, animation.facing_vector)
			if candidate != null and (focused_pot == null or candidate.global_position.distance_squared_to(point) < focused_pot.global_position.distance_squared_to(point)):
				focused_pot = candidate
	if focused_pot == null:
		return
	var pot: Pot = focused_pot
	pot.refresh((pot.get_parent().get_parent() as Garden).time_manager.now())
	var allowed: bool = pot.can_plant(selection.get_selected_item()) if pot.definition == null else (pot.is_mature() or (selection.get_selected_action() == &"water" and pot.can_water()))
	pot.set_focused(true, allowed)
	global_position = pot.global_position
	if pot.definition == null:
		prompt.text = "Chọn hạt hoa · Chuột phải: gieo"
	elif pot.is_mature():
		prompt.text = "E: thu hoa" if selection.inventory.capacity_for(pot.definition.harvest_item) >= pot.definition.harvest_amount else "Túi đồ đầy"
	elif pot.can_water():
		prompt.text = "Chọn bình tưới · Chuột phải: tưới"
	else:
		prompt.text = "%s · %d%%" % [pot.definition.display_name, int(pot.progress * 100)]
	prompt.show()

func prepare_action(requested: StringName) -> StringName:
	refresh()
	_pending = null
	_action = &""
	if focused_pot == null:
		return &""
	_pending = focused_pot
	if requested == &"harvest" and _pending.is_mature():
		_action = &"flower_harvest"
	elif requested != &"harvest" and selection.get_selected_action() == &"water" and _pending.can_water():
		_action = &"flower_water"
	elif requested != &"harvest" and _pending.can_plant(selection.get_selected_item()):
		_action = &"flower_plant"
		_seed = selection.get_selected_item()
		_slot = selection.selected_index
	return _action if not _action.is_empty() else &"blocked"

func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current != &"tool" and current != &"water":
		_action = &""
		_pending = null

func _on_frame_changed() -> void:
	if _action.is_empty() or animation.animated_sprite.frame < impact_frame:
		return
	var action: StringName = _action
	_action = &""
	if not _reachable(_pending) or selection.inventory_open or state.active_action != action:
		_pending = null
		return
	var garden: Garden = _pending.get_parent().get_parent() as Garden
	var now: float = garden.time_manager.now()
	if action == &"flower_plant" and selection.inventory.slot(_slot).item == _seed:
		_pending.plant(selection.inventory, _slot, now)
	elif action == &"flower_water" and selection.get_selected_action() == &"water":
		_pending.water(now)
	elif action == &"flower_harvest":
		_pending.refresh(now)
		_pending.harvest(selection.inventory)
	_pending = null
	refresh()
