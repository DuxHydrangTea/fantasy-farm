class_name StateComponent
extends Node

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
@export var action_harvest: StringName = &"harvest"
@export var action_click_move: StringName = &"click_move"
@export var tool_selection: ToolSelectionComponent
@export var trough_interaction: TroughInteractionComponent
@export var flower_interaction: FlowerInteraction
@export var dust_particles: GPUParticles2D
@export var navigation: PlayerNavigationComponent
var shop_interaction: ShopInteraction


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
		tool_selection.shop_visibility_changed.connect(_on_inventory_visibility_changed)
	transition_to(State.IDLE)

func _physics_process(delta: float) -> void:
	if tool_selection != null and tool_selection.is_menu_open():
		_use_requested = false
		_harvest_requested = false
		movement.stop()
		_update_dust(false)
		return
	if current_state == State.TOOL or current_state == State.WATER:
		_use_requested = false
		_harvest_requested = false
		movement.stop()
		_update_dust(false)
		return
	var keyboard: Vector2 = Input.get_vector(action_left, action_right, action_up, action_down)
	if not keyboard.is_zero_approx():
		if navigation != null:
			navigation.cancel()
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
	var previous_position: Vector2 = movement.body.global_position
	if navigation != null and navigation.has_focus:
		navigation.move(delta)
	elif movement.has_target:
		movement.move_to_target(delta)
	else:
		movement.move(direction, delta)
	# Collision can prevent movement even while input or a destination remains.
	var did_move: bool = movement.body.global_position.distance_squared_to(previous_position) > 0.000001
	transition_to(State.WALK if did_move else State.IDLE)
	animation.play(STATE_NAMES[current_state])
	var is_moving: bool = current_state == State.WALK and movement.body.velocity.length_squared() > 100.0
	_update_dust(is_moving)


func _unhandled_input(event: InputEvent) -> void:
	if tool_selection != null and tool_selection.is_menu_open():
		return
	if current_state == State.TOOL or current_state == State.WATER:
		return
	if (event.is_action_pressed(action_harvest) or event.is_action_pressed(&"interact")) and not event.is_echo():
		if shop_interaction != null and shop_interaction.try_interact():
			get_viewport().set_input_as_handled()
			return
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
	if not click.is_action_pressed(action_click_move):
		return
	if current_state == State.TOOL or current_state == State.WATER:
		return
	# Event coordinates belong to this viewport; undo the camera transform.
	var point: Vector2 = movement.body.get_canvas_transform().affine_inverse() * click.position
	if navigation != null:
		navigation.request_focus(point)
	get_viewport().set_input_as_handled()

func get_selected_tool_action() -> StringName:
	return tool_selection.get_selected_action() if tool_selection != null else &""

func use_selected_tool(requested_action: StringName = &"") -> bool:
	if tool_selection != null and tool_selection.is_menu_open():
		return false
	if current_state == State.TOOL or current_state == State.WATER:
		return false
	var refill_action: StringName = trough_interaction.prepare_action() if trough_interaction != null else &""
	if refill_action == &"blocked":
		return true
	if not refill_action.is_empty():
		active_action = refill_action
		transition_to(State.WATER if refill_action == &"refill_water" else State.TOOL)
		return true
	var flower_action: StringName = flower_interaction.prepare_action(requested_action) if flower_interaction != null else &""
	if flower_action == &"blocked":
		return true
	if not flower_action.is_empty():
		active_action = flower_action
		transition_to(State.WATER if flower_action == &"flower_water" else State.TOOL)
		return true
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
		if navigation != null:
			navigation.cancel()
		movement.cancel_target()
		movement.stop()
		transition_to(State.IDLE)

func reset_after_load() -> void:
	_use_requested = false
	_harvest_requested = false
	if navigation != null:
		navigation.cancel()
	movement.cancel_target()
	movement.stop()
	active_action = &""
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
		if navigation != null:
			navigation.cancel()
		movement.cancel_target()
		movement.stop()
	if current_state != State.WALK:
		_update_dust(false)
	animation.play(STATE_NAMES[current_state], true)
	state_changed.emit(previous, STATE_NAMES[current_state])

func _update_dust(emitting: bool) -> void:
	if dust_particles == null:
		return
	dust_particles.emitting = emitting
	if emitting and movement != null and movement.body != null and dust_particles.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = dust_particles.process_material as ParticleProcessMaterial
		var vel: Vector2 = movement.body.velocity
		if not vel.is_zero_approx():
			var kick_dir: Vector2 = (-vel.normalized() * 0.7 + Vector2(0, -0.6)).normalized()
			mat.direction = Vector3(kick_dir.x, kick_dir.y, 0)


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
