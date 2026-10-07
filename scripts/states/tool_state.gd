class_name ToolState
extends State

@export var action: String = "tool"
signal effect_requested(action: String)

# impact frame là thuộc tính dùng để xác định effect được triển khai sau frame nào. Ví dụ việc tưới nước cần
# 4 frames với frame thứ 4 là frame thu can nước vào, vậy nên effect ướt ô đất sẽ hiện khi đã hoàn thành frame 3
@export var impact_frame: int = 3

var _effect_applied: bool = false

func enter() -> void:
	_effect_applied = false
	movement_component.stop()
	animation_component.action_finished.connect(_on_action_finished)
	animation_component.play(action, true)
	
	animation_component.animated_sprite.frame_changed.connect(_on_frame_changed)
	_on_frame_changed()

func _on_frame_changed() -> void:
	if state_machine.current_state != self or _effect_applied:
		return
	if animation_component.animated_sprite.frame < impact_frame:
		return
	
	_effect_applied = true
	effect_requested.emit(action)
	
func physics_update(_delta: float) -> void:
	movement_component.stop()

func _on_action_finished(finished_action: String) -> void:
	if state_machine.current_state != self:
		return
		
	if finished_action != action:
		return
		
	if actor.has_move_intent():
		state_machine.change_state(&"walk")
	else:
		state_machine.change_to_default()
		
func exit() -> void:
	animation_component.action_finished.disconnect(_on_action_finished)
	animation_component.animated_sprite.frame_changed.disconnect(_on_frame_changed)
