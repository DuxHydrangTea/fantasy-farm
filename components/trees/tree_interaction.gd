class_name TreeInteraction
extends Node
## Hái quả ngay; các thao tác dùng công cụ khóa mục tiêu và commit ở frame tác động.
var player: FarmPlayer
var pending: PerennialTree
var _cell: Vector2i
var _item: ItemDefinition
var _slot: int = -1
var _action: StringName = &""
var marker: Sprite2D

func _ready() -> void:
	player.state.state_changed.connect(_state_changed)
	player.animation.animated_sprite.frame_changed.connect(_impact)
	player.animation.animated_sprite.animation_changed.connect(_impact, CONNECT_DEFERRED)
	marker = Sprite2D.new()
	marker.texture = preload("res://resources/ui/hotbar_selected.tres")
	marker.modulate = Color(0.6, 1.0, 0.6, 0.65)
	marker.z_index = 1
	add_child(marker)

func plantation() -> TreePlantation:
	var world: FarmWorld = player.get_parent() as FarmWorld
	return world.trees if world != null else null

func _physics_process(_delta: float) -> void:
	marker.hide()
	var system: TreePlantation = plantation()
	var item: ItemDefinition = player.selection.get_selected_item()
	if system == null or item == null or not item.crop is TreeDefinition or player.selection.is_menu_open():
		return
	var cell: Vector2i = system.planting_cell(player.global_position + player.animation.facing_vector * 32, (item.crop as TreeDefinition).kind)
	marker.global_position = system.point_for(cell)
	marker.modulate = Color(0.6, 1, 0.6, 0.65) if system.can_place(cell, item.crop as TreeDefinition) else Color(1, 0.3, 0.3, 0.65)
	marker.visible = system.in_region(player.global_position) and player.global_position.distance_to(marker.global_position) <= 64

func prepare_action(requested: StringName = &"") -> StringName:
	var system: TreePlantation = plantation()
	if system == null:
		return &""
	var target: InteractionTarget = player.interactions.resolver.resolve()
	if target != null and target.kind == InteractionTarget.Kind.TREE:
		return prepare_target(target.node as PerennialTree, requested)
	var point: Vector2 = player.global_position + player.animation.facing_vector * 32
	var item: ItemDefinition = player.selection.get_selected_item()
	if item != null and item.crop is TreeDefinition and requested != &"harvest":
		_item = item
		_slot = player.selection.selected_index
		_cell = system.planting_cell(point, (item.crop as TreeDefinition).kind)
		if player.global_position.distance_to(system.point_for(_cell)) > 64 or not system.can_place(_cell, item.crop as TreeDefinition):
			return &"blocked"
		pending = null
		_action = &"tree_plant"
		return _action
	# Không cho cuốc đất gieo rau bên trong khu dành riêng cho cây lâu năm.
	return &"blocked" if system.in_region(point) else &""

func prepare_target(tree: PerennialTree, requested: StringName = &"") -> StringName:
	_action = &""
	if not is_instance_valid(tree) or tree.removed or player.global_position.distance_to(tree.global_position) > 32:
		return &"blocked"
	pending = tree
	_item = player.selection.get_selected_item()
	_slot = player.selection.selected_index
	var tool: bool = _item != null and _item.item_type in [ItemDefinition.ItemType.TOOL, ItemDefinition.ItemType.HOE]
	if tree is FruitTree:
		var fruit: FruitTree = tree as FruitTree
		if tool and _item.tool_type == ItemDefinition.ToolType.HOE and requested != &"harvest":
			_action = &"tree_uproot"
		elif tool and _item.tool_type == ItemDefinition.ToolType.WATERING_CAN and fruit.can_water() and requested != &"harvest":
			_action = &"tree_water"
		elif fruit.has_fruit():
			_action = &"tree_harvest"
	elif tree is TimberTree and tool:
		var timber: TimberTree = tree as TimberTree
		if timber.stump and _item.tool_type == ItemDefinition.ToolType.HOE:
			_action = &"tree_dig"
		elif not timber.stump and timber.is_mature() and _item.tool_type == ItemDefinition.ToolType.AXE:
			_action = &"tree_chop"
	return _action if not _action.is_empty() else &"blocked"

func _state_changed(_previous: StringName, current: StringName) -> void:
	if current != &"tool" and current != &"water":
		_action = &""
		pending = null

func harvest_now() -> bool:
	var fruit: FruitTree = pending as FruitTree
	_action = &""
	pending = null
	var system: TreePlantation = plantation()
	if system == null or not is_instance_valid(fruit) or fruit.removed or player.selection.is_menu_open() or player.global_position.distance_to(fruit.global_position) > 32:
		return false
	system.advance(system.world.farming.time_manager.now())
	return fruit.harvest(player.selection.inventory)

func _impact() -> void:
	if _action.is_empty() or not player.animation.impact_reached(player.farming_actions.impact_frame):
		return
	var action: StringName = _action
	_action = &"" # Xóa trước signal đồng bộ để tránh nhận thưởng lặp.
	var system: TreePlantation = plantation()
	if system == null or player.selection.is_menu_open() or player.state.active_action != action:
		return
	if player.selection.selected_index != _slot or player.selection.get_selected_item() != _item:
		return
	var now: float = system.world.farming.time_manager.now()
	system.advance(now)
	var bag: InventoryComponent = player.selection.inventory
	if action == &"tree_plant":
		if player.global_position.distance_to(system.point_for(_cell)) <= 64:
			system.plant(_cell, bag, _slot, _item, now)
		return
	if not is_instance_valid(pending) or pending.removed or player.global_position.distance_to(pending.global_position) > 32:
		return
	match action:
		&"tree_water": (pending as FruitTree).water(now)
		&"tree_uproot": (pending as FruitTree).uproot(bag)
		&"tree_chop": (pending as TimberTree).chop(bag)
		&"tree_dig": (pending as TimberTree).dig(bag)
	pending = null
