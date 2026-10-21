class_name SoilFocusComponent
extends Node2D

@export var actions: FarmingActionComponent
@export var available_color: Color = Color.WHITE
@export var blocked_color: Color = Color(1.0, 0.35, 0.35, 0.9)

var focused_cell: Vector2i = Vector2i.ZERO
var actionable: bool = false
@export var marker: Sprite2D

func _ready() -> void:
	hide()

func _physics_process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if actions == null:
		hide()
		return
	if actions.state.tool_selection != null and actions.state.tool_selection.is_menu_open():
		hide()
		return
	if actions.state.interactions != null:
		var target: InteractionTarget = actions.state.interactions.focused
		if target != null and target.valid() and target.kind != InteractionTarget.Kind.CROP:
			hide()
			return
	if actions.state.trough_interaction != null and actions.state.trough_interaction.focused_trough != null:
		hide()
		return
	if actions.state.flower_interaction != null and actions.state.flower_interaction.focused_pot != null:
		hide()
		return
	var farming: FarmingController = actions.get_farming_controller()
	if farming == null or farming.farmland == null or farming.farmland.tile_set == null:
		hide()
		return
	var land: TileMapLayer = farming.farmland
	focused_cell = actions.get_focused_cell()
	var center: Vector2 = land.to_global(land.map_to_local(focused_cell))
	var ground: TileMapLayer = farming.ground
	if ground == null or ground.tile_set == null or ground.get_cell_source_id(ground.local_to_map(ground.to_local(center))) == -1:
		hide()
		return
	global_transform = Transform2D(land.global_transform.x, land.global_transform.y, center)
	marker.scale = Vector2(land.tile_set.tile_size) / marker.texture.get_size()
	var actor: PhysicsBody2D = actions.get_parent() as PhysicsBody2D
	var selected_action: StringName = actions.state.get_selected_tool_action()
	if actions.state.current_state == StateComponent.State.TOOL or actions.state.current_state == StateComponent.State.WATER:
		selected_action = actions.get_action()
	if selected_action == &"fertilize":
		actionable = farming.fertilizer_error(focused_cell, actor).is_empty()
	elif selected_action == &"plant":
		actionable = farming.can_plant(focused_cell, actor)
	elif selected_action == &"harvest":
		actionable = farming.can_harvest(focused_cell)
	elif selected_action == &"tool":
		actionable = farming.can_till(focused_cell, actor)
	elif selected_action == &"water":
		actionable = farming.can_water(focused_cell, actor)
	else:
		actionable = false
		hide()
		return
	marker.modulate = available_color if actionable else blocked_color
	show()
