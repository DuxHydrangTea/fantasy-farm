class_name SoilFocusComponent
extends Node2D

@export var actions: FarmingActionComponent
@export var available_color: Color = Color.WHITE
@export var blocked_color: Color = Color(1.0, 0.35, 0.35, 0.9)

var focused_cell: Vector2i = Vector2i.ZERO
var actionable: bool = false
@export var marker: Sprite2D
var area_preview: Array[Dictionary] = []

func _ready() -> void:
	hide()

func _physics_process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	area_preview.clear()
	marker.show()
	queue_redraw()
	actionable = false
	if actions == null:
		hide()
		return
	if actions.state.tool_selection != null and actions.state.tool_selection.is_menu_open():
		hide()
		return
	if actions.state.interactions != null:
		var target: InteractionTarget = actions.state.interactions.focused
		if target != null and target.valid():
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
	if not actions.upgrade_kind().is_empty():
		var targets: Array[Vector2i] = actions.target_cells()
		var found: bool = false
		for cell: Vector2i in targets:
			found = found or _is_farming_cell(farming, cell)
		if not found:
			hide()
			return
		area_preview = actions.preview()
		for row: Dictionary in area_preview:
			actionable = actionable or row.ready
		global_transform = land.global_transform
		marker.hide()
		show()
		queue_redraw()
		return
	if not _is_farming_cell(farming, focused_cell):
		hide()
		return
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
	var selection: ToolSelectionComponent = actions.state.tool_selection
	var item: ItemDefinition = selection.get_selected_item() if selection != null else null
	if item != null and ((selected_action == &"tool" and item.tool_type == ItemDefinition.ToolType.AXE) or (selected_action == &"plant" and not item.crop is CropDefinition)):
		hide()
		return
	if selected_action == &"fertilize":
		actionable = (farming.root_error(focused_cell, actor) if item != null and item.booster_kind == ItemDefinition.BoosterKind.ROOT_TONIC else farming.fertilizer_error(focused_cell, actor)).is_empty()
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

func _draw() -> void:
	if area_preview.is_empty() or actions == null or actions.farming == null:
		return
	var land: TileMapLayer = actions.farming.farmland
	var size: Vector2 = Vector2(land.tile_set.tile_size)
	for row: Dictionary in area_preview:
		var color: Color = Color(0.3, 1.0, 0.5, 0.85) if row.ready else Color(1.0, 0.75, 0.2, 0.85) if row.valid else blocked_color
		var rect: Rect2 = Rect2(land.map_to_local(row.cell) - size * 0.5 + Vector2.ONE, size - Vector2.ONE * 2)
		draw_rect(rect, Color(color, 0.12), true)
		draw_rect(rect, color, false, 1.0)

func _is_farming_cell(farming: FarmingController, cell: Vector2i) -> bool:
	# Keep blocked/locked plots visible, but ordinary grass and paths have no target.
	if farming.land != null and LandExpansionState.REGION.has_point(cell):
		return true
	if farming.get_crop(cell) != null or farming.get_soil_state(cell) != FarmingController.Soil.UNTILLED:
		return true
	var data: TileData = farming.farmland.get_cell_tile_data(cell)
	if data != null:
		for permission: StringName in [&"can_till", &"can_water", &"can_plant"]:
			if data.has_custom_data(permission) and data.get_custom_data(permission) == true:
				return true
	return false
