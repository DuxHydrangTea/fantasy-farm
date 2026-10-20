class_name TroughInteractionComponent
extends Node2D
## Player-side adapter for any AnimalTrough. StateComponent owns input/animation.
@export var selection: ToolSelectionComponent
@export var animation: AnimationComponent
@export var state: StateComponent
@export_range(8.0, 64.0) var reach: float = 30.0
@export var impact_frame: int = 3
@export var prompt: Label
var focused_trough: AnimalTrough
var _pending: AnimalTrough
var _action: StringName = &""
var _water_item: ItemDefinition
var _water_slot: int = -1
var _feedback: String = ""
var _feedback_until: int = 0

func _ready() -> void:
	# Render at UI resolution, independently of camera zoom and fractional motion.
	var prompt_layer: CanvasLayer = CanvasLayer.new()
	prompt_layer.name = "PromptLayer"
	prompt_layer.layer = 9
	add_child(prompt_layer)
	prompt.reparent(prompt_layer)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.state_changed.connect(_on_state_changed)
	animation.animated_sprite.frame_changed.connect(_on_frame_changed)
	animation.animated_sprite.animation_changed.connect(_on_frame_changed, CONNECT_DEFERRED)
	refresh()

func _physics_process(_delta: float) -> void:
	refresh()

func can_reach(trough: AnimalTrough) -> bool:
	if not is_instance_valid(trough) or trough.is_queued_for_deletion() or not trough.is_inside_tree():
		return false
	if global_position.distance_to(trough.global_position) > reach:
		return false
	var actor: CollisionObject2D = get_parent() as CollisionObject2D
	var exclusions: Array[RID] = []
	if actor != null:
		exclusions.append(actor.get_rid())
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, trough.global_position + Vector2(0, -4), 1, exclusions)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == trough

func find_trough() -> AnimalTrough:
	var nearest: AnimalTrough
	var distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
		var trough: AnimalTrough = node as AnimalTrough
		if not can_reach(trough):
			continue
		var candidate: float = global_position.distance_squared_to(trough.global_position)
		if candidate < distance:
			nearest = trough
			distance = candidate
	return nearest

func has_watering_can() -> bool:
	var item: ItemDefinition = selection.get_selected_item() if selection != null else null
	return item != null and item.item_type == ItemDefinition.ItemType.TOOL and item.tool_type == ItemDefinition.ToolType.WATERING_CAN

func refill_hint(trough: AnimalTrough) -> String:
	if trough.stock >= trough.capacity:
		return "Máng đã đầy"
	if trough.kind == AnimalTrough.Kind.WATER:
		return "[E] Thêm nước" if has_watering_can() else "Chọn bình tưới để thêm nước"
	if trough.feed_item == null:
		return "Máng chưa được chọn loại thức ăn"
	if selection.inventory.count_item(trough.feed_item.item_id) == 0:
		return "Cần " + trough.feed_item.display_name
	if trough.feed_items_needed(selection.inventory) == 0:
		return "Chưa đủ chỗ cho 1 gói thức ăn"
	return "[E] Thêm thức ăn"

func can_refill(trough: AnimalTrough) -> bool:
	if trough.stock >= trough.capacity:
		return false
	return has_watering_can() if trough.kind == AnimalTrough.Kind.WATER else trough.feed_items_needed(selection.inventory) > 0

func refresh() -> void:
	if selection == null or selection.is_menu_open():
		focused_trough = null
		prompt.hide()
		return
	focused_trough = find_trough()
	if focused_trough == null:
		prompt.hide()
		return
	var title: String = "Thức ăn" if focused_trough.kind == AnimalTrough.Kind.FOOD else "Nước"
	var hint: String = _feedback if Time.get_ticks_msec() < _feedback_until else refill_hint(focused_trough)
	prompt.text = "%s %d/%d\n%s" % [title, focused_trough.stock, focused_trough.capacity, hint]
	prompt.reset_size()
	var anchor: Vector2 = get_global_transform_with_canvas() * Vector2(0.0, -44.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired: Vector2 = anchor - Vector2(prompt.size.x * 0.5, prompt.size.y)
	prompt.position = Vector2(
		clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - prompt.size.x - 8.0)),
		clampf(desired.y, 8.0, maxf(8.0, viewport_size.y - prompt.size.y - 8.0))
	).round()
	prompt.show()

## Empty lets farming proceed; blocked consumes the input and explains the reason.
func prepare_action() -> StringName:
	_pending = null
	_action = &""
	refresh()
	if focused_trough == null:
		return &""
	if not can_refill(focused_trough):
		return &"blocked"
	_pending = focused_trough
	animation.update_facing_direction(_pending.global_position - global_position)
	_action = &"refill_food" if _pending.kind == AnimalTrough.Kind.FOOD else &"refill_water"
	_water_item = selection.get_selected_item()
	_water_slot = selection.selected_index
	return _action

func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current != &"tool" and current != &"water":
		_pending = null
		_action = &""

func _on_frame_changed() -> void:
	if _action.is_empty() or not animation.impact_reached(impact_frame):
		return
	if not is_instance_valid(_pending):
		_action = &""
		_pending = null
		return
	var action: StringName = _action
	var trough: AnimalTrough = _pending
	_action = &""
	_pending = null
	if not can_reach(trough) or selection.is_menu_open() or state.active_action != action:
		return
	var added: int = 0
	if action == &"refill_food":
		added = trough.refill_from_inventory(selection.inventory)
	elif action == &"refill_water" and selection.inventory.slot(_water_slot).item == _water_item:
		added = trough.refill(trough.water_per_use)
	_feedback = "Đã thêm %d" % added if added > 0 else refill_hint(trough)
	_feedback_until = Time.get_ticks_msec() + 1000
	refresh()
