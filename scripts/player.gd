class_name Player
extends CharacterBase

@export var inventory: Inventory
@onready var tool_state: ToolState = $StateMachine/ToolState
@onready var interaction_focus: InteractionFocusComponent = $InteractionFocusComponent
@onready var ui_controller: PlayerUIComponent = $PlayerUIController

var _pending_action: ActionContext

func _ready() -> void:
	super._ready()
	
	tool_state.action_started.connect(_on_tool_started)
	tool_state.action_ended.connect(_on_tool_ended)
	tool_state.effect_requested.connect(_on_effect_requested)
	
	ui_controller.inventory_open_changed.connect(_on_inventory_open_changed)
	_on_inventory_open_changed(ui_controller.is_inventory_open())

func _on_tool_started() -> void:
	interaction_focus.locked = true
	
func _on_tool_ended() -> void:
	_pending_action = null
	interaction_focus.locked = false
	
func _on_effect_requested() -> void:
	if _pending_action == null:
		return
	_pending_action.execute_once()

func _on_inventory_open_changed(is_open: bool) -> void:
	interaction_focus.active = not is_open

func _exit_tree() -> void:
	_pending_action = null

func use_selected_item() -> void:
	if ui_controller.is_inventory_open():
		return
	
	if not (
		state_machine.current_state is IdleState
		or state_machine.current_state is WalkState
	):
		return
		
	interaction_focus.refresh_focus()
	
	var target := interaction_focus.get_focused_target()
	var slot := ui_controller.hotbar.get_selected_slot()
	
	var context := Interactable.prepare_for(
		target,
		slot,
		inventory
	)
	
	if context == null:
		return
		
	if not context.requires_animation():
		context.execute_once()
		return
		
	_pending_action = context
	tool_state.action = context.animation_action
	state_machine.transition_to(tool_state)
