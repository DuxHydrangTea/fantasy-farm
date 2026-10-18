class_name StateComponent
extends Node

const ToolSelection = preload("res://components/tool_selection_component.gd")

# Component adaptation of the Godot skill's state-machine and top-down templates.
signal state_changed(previous: StringName, current: StringName)

enum State { IDLE, WALK, TOOL, WATER }
const STATE_NAMES: Array[StringName] = [&"idle", &"walk", &"tool", &"water"]

@export var movement: MovementComponent
@export var animation: AnimationComponent
@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_up"
@export var action_down: StringName = &"move_down"
@export var action_use_item: StringName = &"use_item"
@export var tool_selection: ToolSelection

var current_state: State = State.IDLE
var _initialized: bool = false
var _use_requested: bool = false
var active_action: StringName = &""
var _harvest_requested: bool = false

func _ready() -> void:
	assert(movement != null and animation != null, "StateComponent requires movement and animation components")
	animation.action_finished.connect(_on_action_finished)
	if tool_selection != null:
		tool_selection.inventory_visibility_changed.connect(_on_inventory_visibility_changed)
	transition_to(State.IDLE)

func _physics_process(delta: float) -> void:
	if tool_selection != null and tool_selection.inventory_open:
		_use_requested = false
		_harvest_requested = false
		movement.stop()
		return
	if current_state == State.TOOL or current_state == State.WATER:
		_use_requested = false
		_harvest_requested = false
		movement.stop()
		return
	var keyboard: Vector2 = Input.get_vector(action_left, action_right, action_up, action_down)
	if not keyboard.is_zero_approx():
		movement.cancel_target()
	var direction: Vector2 = keyboard if not keyboard.is_zero_approx() else movement.target_direction()
	animation.update_facing_direction(direction)
	if _harvest_requested:
		_harvest_requested = false
		if use_selected_tool(&"harvest"):
			return
	if _use_requested:
		_use_requested = false
		if use_selected_tool():
			return
	if movement.has_target:
		movement.move_to_target(delta)
		if not movement.has_target:
			direction = Vector2.ZERO
	else:
		movement.move(direction, delta)
	transition_to(State.IDLE if direction.is_zero_approx() else State.WALK)
	animation.play(STATE_NAMES[current_state])

func _unhandled_input(event: InputEvent) -> void:
	if tool_selection != null and tool_selection.inventory_open:
		return
	if current_state == State.TOOL or current_state == State.WATER:
		return
	if event is InputEventKey and event.physical_keycode == KEY_E and event.is_pressed() and not event.is_echo():
		_harvest_requested = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(action_use_item) and not event.is_echo():
		_use_requested = true
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
		_use_requested = true
		get_viewport().set_input_as_handled()
		return
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if current_state == State.TOOL or current_state == State.WATER:
		return
	# Event coordinates belong to this viewport; undo the camera transform.
	movement.set_target(movement.body.get_canvas_transform().affine_inverse() * click.position)
	get_viewport().set_input_as_handled()

func get_selected_tool_action() -> StringName:
	return tool_selection.get_selected_action() if tool_selection != null else &""

func use_selected_tool(requested_action: StringName = &"") -> bool:
	if tool_selection != null and tool_selection.inventory_open:
		return false
	if current_state == State.TOOL or current_state == State.WATER:
		return false
	active_action = requested_action if requested_action == &"harvest" else get_selected_tool_action()
	match active_action:
		&"tool", &"plant", &"harvest":
			transition_to(State.TOOL)
		&"water":
			transition_to(State.WATER)
		_:
			return false
	return true

func _on_inventory_visibility_changed(open: bool) -> void:
	if open:
		_use_requested = false
		_harvest_requested = false
		movement.cancel_target()
		movement.stop()
		transition_to(State.IDLE)

func transition_to(next_state: State) -> void:
	if _initialized and next_state == current_state:
		return
	var previous: StringName = STATE_NAMES[current_state] if _initialized else &""
	current_state = next_state
	_initialized = true
	if current_state != State.TOOL and current_state != State.WATER:
		active_action = &""
	if current_state == State.TOOL or current_state == State.WATER:
		movement.cancel_target()
		movement.stop()
	animation.play(STATE_NAMES[current_state], true)
	state_changed.emit(previous, STATE_NAMES[current_state])

func _movement_direction() -> Vector2:
	return Input.get_vector(action_left, action_right, action_up, action_down)

func _on_action_finished(action: String) -> void:
	if current_state != State.TOOL and current_state != State.WATER:
		return
	if action != String(STATE_NAMES[current_state]):
		return
	var direction: Vector2 = _movement_direction()
	animation.update_facing_direction(direction)
	transition_to(State.IDLE if direction.is_zero_approx() else State.WALK)
