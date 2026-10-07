class_name Player
extends CharacterBase

# if you want to define _ready(), you must have to call super._ready()

@onready var tool_state: ToolState = $StateMachine/ToolState
@export var farm_land: FarmLand
@export var tool_reach: float = 16.0
var focused_plot: FarmPlot
var _target_plot: FarmPlot

func _ready() -> void:
	super._ready()
	tool_state.effect_requested.connect(_on_tool_effect_requested)

func _process(_delta: float) -> void:
	if state_machine.current_state is ToolState:
		return
	
	var next_plot: FarmPlot = null
	
	if is_instance_valid(farm_land):
		var target_position = (
			global_position 
			+ animation_component.facing_vector * tool_reach	
		)
		next_plot = farm_land.get_plot_at_world(target_position)
	
	set_focused_plot(next_plot)
		

func use_tool(action: String) -> void:
	if not (state_machine.current_state is IdleState or state_machine.current_state is WalkState):
		return

	_target_plot = null
	
	if action == "water":
		if not is_instance_valid(focused_plot):
			return
		
		_target_plot = focused_plot
	tool_state.action = action
	state_machine.change_state(&"tool")

func set_focused_plot(next_plot: FarmPlot) -> void:
	if is_instance_valid(focused_plot) and focused_plot == next_plot:
		return
		
	if is_instance_valid(focused_plot):
		focused_plot.set_focused(false)
	
	focused_plot = next_plot
	
	if is_instance_valid(focused_plot):
		focused_plot.set_focused(true)

func _on_tool_effect_requested(action: String) -> void:
	if action != "water":
		return
		
	if not is_instance_valid(_target_plot):
		return
	
	_target_plot.water()
