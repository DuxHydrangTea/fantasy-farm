class_name UsingTool
extends ActorState

signal finished
signal impact_requested

@export var animation_component: AnimationComponent
@export_range(0, 5) var impact_frame: int = 3

var animation_action: StringName = &"tool"
var _impact_applied: bool = false

func _ready() -> void:
	pass

func enter() -> void:
	super.enter()
	assert(animation_component != null, "Locomotion thiếu AnimationComponent.")
	_impact_applied = false
	animation_component.action_finished.connect(_on_action_finished)
	
	if not animation_component.play_action(animation_action):
		finished.emit()
		return
	
	animation_component.anim_sprite.frame_changed.connect(_on_frame_changed)
	_on_frame_changed()
	
func _on_frame_changed() -> void:
	if _impact_applied:
		return
	
	if animation_component.anim_sprite.frame < impact_frame:
		return
	
	_impact_applied = true
	impact_requested.emit()

func _on_action_finished() -> void:
	_on_frame_changed()
	finished.emit()

func exit() -> void:
	animation_component.action_finished.disconnect(_on_action_finished)
	
	if animation_component.anim_sprite.frame_changed.is_connected(_on_frame_changed):
		animation_component.anim_sprite.frame_changed.disconnect(_on_frame_changed)
	
	super.exit()
