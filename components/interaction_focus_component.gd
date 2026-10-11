class_name InteractionFocusComponent
extends Area2D

@export_range(0.05, 1.0) var update_interval: float = 0.1
@export_range(0.0, 32.0) var facing_weight: float = 12.0
@export_range(0.0, 16.0) var switch_margin: float = 4.0

var active: bool = true
var locked: bool = false
var _candidates: Array[FocusComponent] = []
var _focused: FocusComponent
var _elapsed: float = 0.0

@onready var actor: CharacterBase = get_parent() as CharacterBase

func _ready() -> void:
	if actor == null:
		push_error("InteractionFocusComponent cần nằm dưới CharacterBase.")
		set_physics_process(false)
		return
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	if not active:
		_elapsed = 0.0
		_set_focused(null)
		return
	
	if locked:
		return
	
	_elapsed += delta
	
	if _elapsed < update_interval:
		return
	
	_elapsed = 0.0
	refresh_focus()

func _is_eligible(candidate: FocusComponent) -> bool:
	if not is_instance_valid(candidate):
		return false
		
	if not candidate.focus_enabled:
		return false

	return is_instance_valid(candidate.get_interaction_target())

func refresh_focus() -> void:
	if not active or locked:
		return
	
	var best: FocusComponent = null
	var best_score: float = INF
	
	for index in range(_candidates.size() - 1, -1, -1):
		var candidate := _candidates[index]
		
		if not is_instance_valid(candidate):
			_candidates.remove_at(index)
			continue
		
		if not _is_eligible(candidate):
			continue
		
		var score := _get_score(candidate)
		
		if score < best_score:
			best = candidate
			best_score = score
	
	if (
		is_instance_valid(best)
		and best != _focused
		and _is_eligible(_focused)
		and _candidates.has(_focused)
	):
		var current_score := _get_score(_focused)
		
		if best_score >= current_score - switch_margin:
			return
	
	_set_focused(best)

func _get_score(candidate: FocusComponent) -> float:
	var offset := candidate.global_position - global_position
	var distance := offset.length()
	
	if distance < 0.001:
		return 0.0
	
	var facing := actor.animation_component.facing_vector
	var alignment := facing.dot(offset / distance)
	
	return distance - alignment * facing_weight

func _set_focused(next: FocusComponent) -> void:
	if _focused == next:
		return
		
	if is_instance_valid(_focused):
		_focused.set_focused(false)
	
	_focused = next
	
	if is_instance_valid(_focused):
		_focused.set_focused(true)

func _on_area_entered(area: Area2D) -> void:
	if not area is FocusComponent:
		return
		
	var candidate := area as FocusComponent
	
	if _candidates.has(candidate):
		return
	
	_candidates.append(candidate)
	

func _on_area_exited(area: Area2D) -> void:
	if not area is FocusComponent:
		return
		
	var candidate := area as FocusComponent
	_candidates.erase(candidate)
	
	if _focused == candidate:
		_set_focused(null)
		
func get_focused_target() -> Node2D:
	if not active or not _is_eligible(_focused):
		return null
		
	return _focused.get_interaction_target()
	
