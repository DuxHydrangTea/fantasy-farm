class_name TroughInteractionComponent
extends Node2D
## Điều phối người chơi nạp thức ăn, nước vào máng tại frame tác động hoạt ảnh.
## StateComponent quản lý input và trạng thái công cụ; component này giữ mục tiêu
## và kiểm tra lại tầm, vật phẩm, menu trước khi nạp.

## Phát loại thao tác và số sự kiện sau lần nạp thành công.
signal refill_committed(condition: StringName, amount: int)
## Lựa chọn công cụ và inventory người chơi.
@export var selection: ToolSelectionComponent
## Hoạt ảnh cung cấp frame tác động và hướng nhìn.
@export var animation: AnimationComponent
## Máy trạng thái hành động người chơi.
@export var state: StateComponent
## Khoảng cách tiếp cận máng tối đa.
@export_range(8.0, 64.0) var reach: float = 30.0
## Frame dự kiến áp dụng thao tác.
@export var impact_frame: int = 3
## Nhãn hiển thị hướng dẫn và kết quả.
@export var prompt: Label
## Máng gần nhất đang được nhắm.
var focused_trough: AnimalTrough
var _pending: AnimalTrough
var _action: StringName = &""
var _water_item: ItemDefinition
var _auto_fill: bool = false
var _water_slot: int = -1
var _feedback: String = ""
var _feedback_amount: int = 0
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

## Kiểm tra máng hợp lệ, trong tầm và đường nhìn không bị vật khác chặn.
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

## Tìm máng gần nhất có thể tiếp cận, hoặc null.
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

## Kiểm tra vật phẩm đang chọn là bình tưới.
func has_watering_can() -> bool:
	var item: ItemDefinition = selection.get_selected_item() if selection != null else null
	return item != null and item.item_type == ItemDefinition.ItemType.TOOL and item.tool_type == ItemDefinition.ToolType.WATERING_CAN


## Lấy inventory kho vật tư của thế giới, hoặc null nếu không có.
func feed_inventory() -> InventoryComponent:
	var world: FarmWorld = get_parent().get_parent() as FarmWorld
	return world.storages.inventory("farm_supply_storage") if world != null and world.storages != null else null

## Đếm gói thức ăn phù hợp máng trong kho vật tư.
func feed_stock(trough: AnimalTrough) -> int:
	var source: InventoryComponent = feed_inventory()
	return source.count_item(trough.feed_item.item_id) if source != null and trough.feed_item != null else 0

## Tạo hướng dẫn đã dịch cho thao tác nạp thông thường.
func refill_hint(trough: AnimalTrough) -> String:
	if trough.stock >= trough.capacity:
		return tr("Trough is full")
	if trough.kind == AnimalTrough.Kind.WATER:
		return tr("[E] Add water") if has_watering_can() else tr("Select a watering can to add water")
	if trough.feed_item == null:
		return tr("No feed type assigned to this trough")
	if feed_stock(trough) == 0:
		return tr("Supply storage requires {item}").format({"item": tr(trough.feed_item.display_name)})
	if trough.feed_items_needed(feed_inventory()) == 0:
		return tr("Not enough room for one feed pack")
	return tr("[E] Add feed · Storage: {count}").format({"count": feed_stock(trough)})

## Kiểm tra máng chưa đầy và có bình tưới hoặc gói thức ăn phù hợp.
func can_refill(trough: AnimalTrough) -> bool:
	if trough.stock >= trough.capacity:
		return false
	return has_watering_can() if trough.kind == AnimalTrough.Kind.WATER else trough.feed_items_needed(feed_inventory()) > 0

## Cập nhật máng đang nhắm và vị trí, nội dung nhãn theo trạng thái hiện tại.
func refresh() -> void:
	if selection == null or selection.is_menu_open():
		focused_trough = null
		prompt.hide()
		return
	focused_trough = find_trough()
	if focused_trough == null:
		prompt.hide()
		return
	var title: String = tr("Feed") if focused_trough.kind == AnimalTrough.Kind.FOOD else tr("Water")
	var hint: String = tr(_feedback).format({"amount": _feedback_amount}) if not _feedback.is_empty() and Time.get_ticks_msec() < _feedback_until else refill_hint(focused_trough)
	prompt.text = tr("{kind} {stock}/{capacity}\n{hint}").format({"kind": title, "stock": focused_trough.stock, "capacity": focused_trough.capacity, "hint": hint})
	prompt.reset_size()
	var anchor: Vector2 = get_global_transform_with_canvas() * Vector2(0.0, -44.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired: Vector2 = anchor - Vector2(prompt.size.x * 0.5, prompt.size.y)
	prompt.position = Vector2(
		clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - prompt.size.x - 8.0)),
		clampf(desired.y, 8.0, maxf(8.0, viewport_size.y - prompt.size.y - 8.0))
	).round()
	prompt.visible = not (get_parent() is FarmPlayer and (get_parent() as FarmPlayer).interactions != null)

## Chuẩn bị nạp máng đang nhắm. Chuỗi rỗng cho phép xét hành động đất,
## blocked cho biết có máng nhưng không thể nạp, còn lại là mã hoạt ảnh.
func prepare_action() -> StringName:
	_auto_fill = false
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
		var world: FarmWorld = get_parent().get_parent() as FarmWorld
		if world != null:
			added = world.storages.refill_feed(trough, _auto_fill)
	elif action == &"refill_water":
		if _auto_fill and inventory_has_can():
			added = trough.refill(trough.capacity - trough.stock)
		elif not _auto_fill and selection.inventory.slot(_water_slot).item == _water_item:
			added = trough.refill(trough.water_per_use)
	_feedback = "Added {amount}" if added > 0 else ""
	if added > 0:
		Sound.play(&"feed_trough" if action == &"refill_food" else &"water_trough")
		refill_committed.emit(action, 1)
	_feedback_amount = added
	_feedback_until = Time.get_ticks_msec() + 1000
	refresh()

## Kiểm tra có bình tưới ở bất kỳ ô nào trong túi.
func inventory_has_can() -> bool:
	for index: int in range(selection.inventory.slot_count):
		var item: ItemDefinition = selection.inventory.slot(index).item
		if item != null and item.item_type == ItemDefinition.ItemType.TOOL and item.tool_type == ItemDefinition.ToolType.WATERING_CAN:
			return true
	return false

## Trả lý do đã dịch khi không thể nạp đầy tự động, hoặc chuỗi rỗng.
func auto_hint(trough: AnimalTrough) -> String:
	if trough.stock >= trough.capacity:
		return tr("Trough is full")
	if trough.kind == AnimalTrough.Kind.WATER:
		return "" if inventory_has_can() else tr("A watering can is required.")
	if trough.feed_item == null:
		return tr("No feed type assigned to this trough")
	if trough.feed_reserve == 0 and feed_stock(trough) == 0:
		return tr("Supply storage requires {item}").format({"item": tr(trough.feed_item.display_name)})
	return ""

## Chuẩn bị nạp đầy máng cụ thể trong tầm, hoặc trả blocked nếu không hợp lệ.
func prepare_target(trough: AnimalTrough) -> StringName:
	_pending = null
	_action = &""
	if not can_reach(trough) or not auto_hint(trough).is_empty():
		return &"blocked"
	_auto_fill = true
	_pending = trough
	animation.update_facing_direction(trough.global_position - global_position)
	_action = &"refill_food" if trough.kind == AnimalTrough.Kind.FOOD else &"refill_water"
	return _action
