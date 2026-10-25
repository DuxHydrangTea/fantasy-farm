class_name FarmingActionComponent
extends Node

@export var animation: AnimationComponent
@export var state: StateComponent
@export var impact_frame: int = 3

@export var farming: FarmingController
var _cell: Vector2i
var _action: StringName = &""
var _seed: ItemDefinition
var _slot_index: int = -1
var upgrades: ToolUpgradeState
var _targets: Array[Vector2i] = []
var last_preview: Array[Dictionary] = []
var last_result: Dictionary = {}
var _storage_seed: bool = false
var _selection_revision: int = -1
var _plant_source: InventoryComponent

func _ready() -> void:
	assert(animation != null and state != null, "Farming actions require animation and state")
	state.state_changed.connect(_on_state_changed)
	animation.animated_sprite.frame_changed.connect(_on_frame_changed)
	animation.animated_sprite.animation_changed.connect(_on_frame_changed, CONNECT_DEFERRED)

func _on_state_changed(_previous: StringName, current: StringName) -> void:
	_action = &""
	if current != &"tool" and current != &"water":
		return
	farming = get_farming_controller()
	if farming == null:
		return
	_cell = _cell_ahead()
	_action = state.active_action if not state.active_action.is_empty() else current
	_targets = target_cells(_action, false)
	if _action == &"tree_dig" and state.tree_interaction != null:
		_targets = state.tree_interaction.dig_targets()
	if _action == &"harvest":
		var crop: Crop = farming.get_crop(_cell)
		if crop != null:
			crop.react(6.0, animation.facing_vector.x)
	if _action == &"plant" and state.tool_selection != null:
		_seed = state.tool_selection.get_selected_item()
		_slot_index = state.tool_selection.selected_index
		_storage_seed = state.tool_selection.uses_storage_seeds()
		_selection_revision = state.tool_selection.revision
		_plant_source = state.tool_selection.planting_inventory()

func get_farming_controller() -> FarmingController:
	return farming if is_instance_valid(farming) else null

func get_focused_cell() -> Vector2i:
	if get_farming_controller() == null:
		return Vector2i.ZERO
	if state.current_state == StateComponent.State.TOOL or state.current_state == StateComponent.State.WATER:
		return _cell
	return _cell_ahead()

func _cell_ahead() -> Vector2i:
	var actor: Node2D = get_parent() as Node2D
	return farming.world_to_cell(actor.global_position) + Vector2i(animation.facing_vector)

func upgrade_kind(action: StringName = &"") -> StringName:
	var chosen: StringName = action if not action.is_empty() else state.active_action if state.current_state in [StateComponent.State.TOOL, StateComponent.State.WATER] else state.get_selected_tool_action()
	var item: ItemDefinition = state.tool_selection.get_selected_item() if state.tool_selection != null else null
	if chosen == &"tool" and item != null and item.tool_type == ItemDefinition.ToolType.AXE:
		return &""
	if chosen == &"plant" and (item == null or not item.crop is CropDefinition):
		return &""
	return FarmingAreaPolicy.tool_for(chosen)

func target_cells(action: StringName = &"", frozen: bool = true) -> Array[Vector2i]:
	if frozen and state.current_state in [StateComponent.State.TOOL, StateComponent.State.WATER] and not _targets.is_empty():
		return _targets.duplicate()
	var kind: StringName = upgrade_kind(action)
	var size: int = upgrades.selected_size(kind) if upgrades != null and not kind.is_empty() else 1
	return FarmingAreaPolicy.cells(farming.world_to_cell((get_parent() as Node2D).global_position), Vector2i(animation.facing_vector), size)

func preview() -> Array[Dictionary]:
	var action: StringName = get_action() if state.current_state in [StateComponent.State.TOOL, StateComponent.State.WATER] else state.get_selected_tool_action()
	var selection: ToolSelectionComponent = state.tool_selection
	last_preview = FarmingAreaPolicy.evaluate(farming, action, target_cells(action), selection.planting_inventory(), selection.selected_index, get_parent() as PhysicsBody2D, selection.get_selected_item(), selection.uses_storage_seeds())
	return last_preview

# Thao tác chỉ commit ở frame chạm đất, không ở thời điểm người chơi vừa bấm nút.
# Chép _action sang biến cục bộ và xóa nó TRƯỚC khi đổi inventory/terrain: các signal phát ra
# có thể gọi frame handler lồng nhau. Nếu xóa sau, một động tác có thể tiêu hạt hoặc thu hoạch hai lần.
# Đổi slot giữa animation không được đổi loại hạt đã chốt lúc bắt đầu, nên kiểm tra _slot_index/_seed.
func _on_frame_changed() -> void:
	if _action.is_empty() or not animation.impact_reached(impact_frame):
		return
	var action: StringName = _action
	_action = &""
	if not is_instance_valid(farming):
		return
	if action == &"tool" and state.current_state == StateComponent.State.TOOL:
		last_result = farming.apply_area(action, _targets, state.tool_selection.inventory if action == &"tool" else null, -1, null, get_parent() as PhysicsBody2D)
	elif action == &"water" and state.current_state == StateComponent.State.WATER:
		last_result = farming.apply_area(action, _targets, state.tool_selection.inventory if action == &"tool" else null, -1, null, get_parent() as PhysicsBody2D)
	elif action == &"plant" and state.current_state == StateComponent.State.TOOL:
		var selection: ToolSelectionComponent = state.tool_selection
		if selection.revision != _selection_revision or selection.is_menu_open():
			return
		if _storage_seed:
			if selection.storage_service != null and selection.planting_inventory() == _plant_source and selection.get_selected_item() == _seed:
				last_result = selection.storage_service.plant_from_storage(_seed.item_id, _selection_revision, _targets)
			return
		var inventory: InventoryComponent = selection.inventory
		# Selection changes cannot redirect the seed or spend a different stack mid-action.
		if state.tool_selection.selected_index == _slot_index and inventory.slot(_slot_index).item == _seed:
			last_result = farming.apply_area(action, _targets, inventory, _slot_index, _seed, get_parent() as PhysicsBody2D)
	elif action == &"harvest" and state.current_state == StateComponent.State.TOOL:
		farming.harvest(_cell, state.tool_selection.inventory)

func get_action() -> StringName:
	return _action if not _action.is_empty() else state.active_action
