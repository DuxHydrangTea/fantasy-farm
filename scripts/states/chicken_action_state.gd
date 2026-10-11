class_name ChickenState
extends State

enum Phase {
	START,
	HOLD,
	FINISH
}

@export var start_action: String = ""
@export var hold_action: String = ""
@export var finish_action: String = ""
@export_range(0.0, 60.0) var hold_seconds: float = 0.0

var _phase: Phase = Phase.HOLD
var _remaining: float = 0.0

func enter() -> void:
	actor.movement_vector = Vector2.ZERO
	movement_component.stop()
	
	animation_component.action_finished.connect(_on_action_finished)
	
	if start_action.is_empty():
		_begin_hold()
	else:
		_phase = Phase.START
		animation_component.play(start_action, true)


func _on_action_finished(action: String) -> void:
	if state_machine.current_state != self:
		return
	
	if _phase == Phase.START and action == start_action:
		_begin_hold()
	elif _phase == Phase.FINISH and action == finish_action:
		state_machine.change_to_default()

func _begin_hold() -> void:
	_phase = Phase.HOLD
	_remaining = hold_seconds
	
	if not hold_action.is_empty():
		animation_component.play(hold_action, true)
	
	if _remaining <= 0:
		_begin_finish()
	
func _begin_finish() -> void:
	if finish_action.is_empty():
		state_machine.change_to_default()
		return
		
	_phase = Phase.FINISH
	animation_component.play(finish_action, true)

func physics_update(_delta: float) -> void:
	movement_component.stop()
	
func update(delta: float) -> void:
	if _phase != Phase.HOLD:
		return
	
	_remaining = maxf(0.0, _remaining - delta)
	
	if _remaining <= 0:
		_begin_finish()

func exit() -> void:
	animation_component.action_finished.disconnect(_on_action_finished)	
	
	
	
