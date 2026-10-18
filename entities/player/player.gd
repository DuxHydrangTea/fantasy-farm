class_name Player
extends CharacterBody2D

@export var movement_component: MovementComponent
@export var player_input_controller: PlayerInputController
@export var facing_component: FacingComponent
@export var animation_component: AnimationComponent
@export var state_machine: ActorStateMachine
@export var locomotion_state: Locomotion
@export var using_tool_state: UsingTool
@export var target_preview: TargetPreview
@export var world_grid: WorldGrid
@export var inventory_component: InventoryComponent
@export var hotbar_view: HotbarView
@export var crop_catalog: CropCatalog

var _selected_tool_action: StringName = &"tool"
var _pending_tool_cell: Vector2i = Vector2i.ZERO
var _pending_tool_action: StringName = &"tool"
var _pending_crop_definition: CropDefinition
var selected_crop: CropDefinition

func _ready() -> void:
	assert(movement_component != null, "Movement Component chưa gán!")
	assert(player_input_controller != null, "Player Input Controller chưa gán!")
	assert(facing_component != null, "Facing Component chưa gán!")
	assert(animation_component != null, "AnimationComponent chưa gán!")
	assert(state_machine != null, "Actor State Machine chưa gán!")
	assert(locomotion_state != null, "Chưa gán Locomotion.")
	assert(using_tool_state != null, "Chưa gán UsingTool.")
	assert(inventory_component != null, "Chưa gán Inventory Component.")
	assert(hotbar_view != null, "Chưa gán HotbarView.")
	assert(crop_catalog != null, "Chưa gán CropCatalog.")
	
	player_input_controller.direction_changed.connect(state_machine.set_direction)
	facing_component.facing_direction_changed.connect(_on_facing_direction_changed)
	player_input_controller.tool_requested.connect(_on_tool_requested)
	using_tool_state.finished.connect(_on_tool_finished, CONNECT_DEFERRED)
	using_tool_state.impact_requested.connect(_on_tool_impact_requested)
	player_input_controller.hotbar_slot_selected.connect(_on_hotbar_slot_requested)
	hotbar_view.contents_changed.connect(_on_hotbar_contents_changed)
	state_machine.start()
	
	var crops_valid := crop_catalog.build_index()
	assert(crops_valid, "Không thể tạo bảng tra cứu cây.")
	
	if world_grid != null:
		world_grid.crop_harvested.connect(_on_crop_harvested)
	
	inventory_component.add_item(&"hoe", 1)
	inventory_component.add_item(&"watering_can", 1)
	inventory_component.add_item(&"carrot_produce", 25)
	inventory_component.add_item(&"carrot_seed", 5)
	
	inventory_component.item_amount_changed.connect(_on_inventory_amount_changed)
	_sync_hotbar_action()

func _on_tool_requested() -> void:
	if state_machine.current_state != locomotion_state:
		return
	_sync_hotbar_action()
	
	if target_preview == null or world_grid == null:
		return
		
	var cell: Vector2i = target_preview.get_target_cell()
	var action: StringName = world_grid.resolve_action(_selected_tool_action, cell)
	
	if action == &"plant":
		if (selected_crop == null or not selected_crop.is_valid()):
			return
		if not inventory_component.has_amount(selected_crop.seed_item.item_id):
			return
	
	if not world_grid.can_use_tool(action, cell):
		return
	_pending_crop_definition = selected_crop if action == &"plant" else null
	_pending_tool_cell = cell
	_pending_tool_action = action
	using_tool_state.animation_action = &"water" if action == &"water" else &"tool"
	state_machine.transition_to(using_tool_state)

func _on_tool_finished() -> void:
	if state_machine.current_state == using_tool_state:
		state_machine.transition_to(locomotion_state)
		_sync_hotbar_action()

func _on_facing_direction_changed(dir: Vector2) -> void:
	animation_component.set_facing(dir)

func _on_tool_impact_requested() -> void:
	if state_machine.current_state != using_tool_state:
		return
	
	if world_grid == null:
		return
	
	match _pending_tool_action:
		&"tool":
			world_grid.till(_pending_tool_cell)
		&"water":
			world_grid.water(_pending_tool_cell)
		&"plant":
			#world_grid.plant(_pending_tool_cell, _pending_crop_definition)
			var definition: CropDefinition = _pending_crop_definition
			if definition == null or not definition.is_valid():
				return
				
			var seed_id: StringName = definition.seed_item.item_id
			if not inventory_component.has_amount(seed_id):
				return
			
			if world_grid.plant(_pending_tool_cell, definition):
				inventory_component.remove_item(seed_id)
		&"harvest":
			world_grid.harvest(_pending_tool_cell)

func _on_tool_selected(action: StringName) -> void:
	if state_machine.current_state != locomotion_state:
		return
	_selected_tool_action = action
	if target_preview != null:
		target_preview.set_tool_action(_selected_tool_action)

func _on_crop_harvested(definition: CropDefinition) -> void:
	inventory_component.add_item(definition.harvest_item.item_id, definition.harvest_amount)

func _refresh_planting_preview() -> void:
	if target_preview == null:
		return
	
	var available: bool = false
	
	if selected_crop != null and selected_crop.is_valid():
		available = inventory_component.has_amount(selected_crop.seed_item.item_id)
		
	target_preview.set_planting_available(available)

func _on_inventory_amount_changed(_item_id: StringName, _total: int) -> void:
	_refresh_planting_preview()

func _on_hotbar_slot_requested(index: int) -> void:
	if state_machine.current_state != locomotion_state:
		return
	
	hotbar_view.select_slot(index)
	_sync_hotbar_action()

func _sync_hotbar_action() -> void:
	var definition: ItemDefinition = hotbar_view.get_selected_item()
	var action: StringName = &""
	
	selected_crop = null
	
	if definition is ToolDefinition:
		var tool: ToolDefinition = definition as ToolDefinition
		if inventory_component.has_amount(tool.item_id):
			action = StringName(tool.action)
	elif definition != null:
		selected_crop = crop_catalog.get_crop_by_seed(definition.item_id)
		if selected_crop != null:
			action = &"plant"

	_on_tool_selected(action)
	_refresh_planting_preview()
		
func _on_hotbar_contents_changed() -> void:
	if state_machine.current_state == locomotion_state:
		_sync_hotbar_action()
