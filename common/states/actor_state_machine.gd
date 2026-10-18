class_name ActorStateMachine
extends Node

@export var initial_state: ActorState

var current_state: ActorState
var _last_direction: Vector2 = Vector2.ZERO

func start() -> void:
	assert(initial_state != null, "Chưa gán Initial State")
	transition_to(initial_state)

func transition_to(next_state: ActorState) -> void:
	assert(next_state != null, "Next State không được null")
	assert(next_state.get_parent() == self, "Next State này phải là child node của Actor State Machine")
	
	if next_state == current_state:
		return
		
	if current_state != null:
		current_state.exit()
		
	current_state = next_state
	current_state.enter()
	current_state.handle_direction(_last_direction)

func set_direction(direction: Vector2) -> void:
	_last_direction = direction
	
	if current_state != null:
		current_state.handle_direction(direction)
