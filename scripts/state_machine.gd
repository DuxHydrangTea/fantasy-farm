class_name StateMachine
extends Node

signal state_changed(from: State, to: State)

@export var initial_state: State
@export var default_state: State

var current_state: State
var states: Dictionary = {}

func init(actor: CharacterBase) -> void:
	for child in get_children():
		if child is State:
			states[_to_key(child.name)] = child
			child.setup(actor, self)
	
	if default_state == null:
		default_state = initial_state
	
	if initial_state == null:
		push_warning("StateMachine (%s): chưa gán initial_state" % owner.name)
		return
	transition_to(initial_state)
	
func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)
		
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func change_state(state_name: StringName) -> void:
	var target: State = states.get(_to_key(state_name))
	if target == null:
		push_warning("StateMachine: không có state '%s'. Hiện có: %s" % [state_name, states.keys()])
		return
	transition_to(target)
	
func change_to_default() -> void:
	if default_state:
		transition_to(default_state)
	
static func _to_key(n: StringName) -> StringName:
	return StringName(String(n).to_lower().trim_suffix("state"))

func transition_to(target: State) -> void:
	if target == null or target == current_state:
		return
	
	var previous := current_state
	if previous:
		previous.exit()
	
	current_state = target
	current_state.enter()
	state_changed.emit(previous, current_state)
