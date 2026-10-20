class_name FlowerInteraction
extends Node2D
## One locked target and one impact per action, sharing the player's tool states.
@export var selection: ToolSelectionComponent
@export var animation: AnimationComponent
@export var state: StateComponent
@export var impact_frame: int = 3
var focused_pot: FlowerPot
var _pending: FlowerPot
var _action: StringName = &""
var _seed: ItemDefinition
var _slot: int = -1
@export var prompt: Label

func _ready() -> void:
	assert(selection != null and animation != null and state != null and prompt != null, "Assign flower interaction components in the Player scene")
	state.state_changed.connect(_on_state_changed)
	animation.animated_sprite.frame_changed.connect(_on_frame_changed)
	animation.animated_sprite.animation_changed.connect(_on_frame_changed, CONNECT_DEFERRED)
	prompt.hide()

func _physics_process(_delta: float) -> void:
	refresh()

func _reachable(pot: FlowerPot) -> bool:
	return is_instance_valid(pot) and pot.global_position.distance_to((get_parent() as Node2D).global_position) <= 28.0

func refresh() -> void:
	if is_instance_valid(focused_pot):
		focused_pot.set_focused(false)
	focused_pot = null
	prompt.hide()
	if selection.is_menu_open():
		return
	var point: Vector2 = (get_parent() as Node2D).global_position
	if not _action.is_empty() and _reachable(_pending):
		focused_pot = _pending
	else:
		for garden: Node in get_tree().get_nodes_in_group(&"flower_gardens"):
			var candidate: FlowerPot = (garden as FlowerGarden).focused_pot(point, animation.facing_vector)
			if candidate != null and (focused_pot == null or candidate.global_position.distance_squared_to(point) < focused_pot.global_position.distance_squared_to(point)):
				focused_pot = candidate
	if focused_pot == null:
		return
	var pot: FlowerPot = focused_pot
	pot.refresh(pot.garden.time_manager.now())
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
	if _action.is_empty() or not animation.impact_reached(impact_frame):
		return
	var action: StringName = _action
	_action = &""
	if not _reachable(_pending) or selection.is_menu_open() or state.active_action != action:
		_pending = null
		return
	var garden: FlowerGarden = _pending.garden
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
