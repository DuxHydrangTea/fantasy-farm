class_name FarmingActionComponent
extends Node

@export var animation: AnimationComponent
@export var state: StateComponent
@export var impact_frame: int = 3

@export var farming: FarmingController
var _cell: Vector2i
var _action: StringName = &""
var _seed: ItemDefinition
var _slot_index: int = -1

func _ready() -> void:
	assert(animation != null and state != null, "Farming actions require animation and state")
	state.state_changed.connect(_on_state_changed)
	animation.animated_sprite.frame_changed.connect(_on_frame_changed)

func _on_state_changed(_previous: StringName, current: StringName) -> void:
	_action = &""
	if current != &"tool" and current != &"water":
		return
	farming = get_farming_controller()
	if farming == null:
		return
	_cell = _cell_ahead()
	_action = state.active_action if not state.active_action.is_empty() else current
	if _action == &"plant" and state.tool_selection != null:
		_seed = state.tool_selection.get_selected_item()
		_slot_index = state.tool_selection.selected_index

func get_farming_controller() -> FarmingController:
	return farming if is_instance_valid(farming) else null

func get_focused_cell() -> Vector2i:
	if get_farming_controller() == null:
		return Vector2i.ZERO
	if state.current_state == StateComponent.State.TOOL or state.current_state == StateComponent.State.WATER:
		return _cell
	return _cell_ahead()

func _cell_ahead() -> Vector2i:
	var actor: Node2D = get_parent() as Node2D
	return farming.world_to_cell(actor.global_position) + Vector2i(animation.facing_vector)

func _on_frame_changed() -> void:
	if _action.is_empty() or animation.animated_sprite.frame < impact_frame:
		return
	var action: StringName = _action
	_action = &""
	if not is_instance_valid(farming):
		return
	if action == &"tool" and state.current_state == StateComponent.State.TOOL:
		farming.till(_cell, get_parent() as PhysicsBody2D)
	elif action == &"water" and state.current_state == StateComponent.State.WATER:
		farming.water(_cell, get_parent() as PhysicsBody2D)
	elif action == &"plant" and state.current_state == StateComponent.State.TOOL:
		var inventory: InventoryComponent = state.tool_selection.inventory
		# Selection changes cannot redirect the seed or spend a different stack mid-action.
		if inventory.slot(_slot_index).item == _seed:
			farming.plant(_cell, inventory, _slot_index, get_parent() as PhysicsBody2D)
	elif action == &"harvest" and state.current_state == StateComponent.State.TOOL:
		farming.harvest(_cell, state.tool_selection.inventory)

func get_action() -> StringName:
	return _action if not _action.is_empty() else state.active_action
