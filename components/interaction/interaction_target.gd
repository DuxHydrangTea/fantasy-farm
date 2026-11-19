class_name InteractionTarget
extends RefCounted
## Đại diện ngắn hạn có kiểu cho một mục tiêu tương tác trong scene.
## Loại mục tiêu quyết định kiểm tra, vị trí và nhãn hành động.

## Các loại mục tiêu được bộ phân giải hỗ trợ.
enum Kind { MERCHANT, LAND, TROUGH, ANIMAL, CROP, FLOWER, BEEHIVE, TREE, ORDER_BOARD, PEN_BOARD, TREE_PLOT_BOARD, TREE_PLOT }
## Node mục tiêu.
var node: Node2D
## Loại mục tiêu xác định cách tương tác.
var kind: Kind
## Người chơi thực hiện tương tác.
var player: FarmPlayer
## Sản phẩm được chọn trên điểm thu chuồng, nếu có.
var product: ItemDefinition
## Ô đất của mục tiêu TREE_PLOT.
var cell: Vector2i = Vector2i.ZERO
## Loại khu cây của mục tiêu TREE_PLOT.
var tree_kind: TreeDefinition.Kind = TreeDefinition.Kind.FRUIT

func _init(target: Node2D, type: Kind, customer: FarmPlayer) -> void:
	node = target
	kind = type
	player = customer

## Tạo mục tiêu cho ô trồng cây lâu năm theo tọa độ ô và loại khu cây.
static func for_tree_plot(display: TreePlotDisplay, plot_cell: Vector2i, plot_kind: TreeDefinition.Kind, customer: FarmPlayer) -> InteractionTarget:
	var target: InteractionTarget = InteractionTarget.new(display, Kind.TREE_PLOT, customer)
	target.cell = plot_cell
	target.tree_kind = plot_kind
	return target

## So sánh hai mục tiêu có trỏ tới cùng đối tượng hoặc cùng ô đất hay không.
func same_target(other: InteractionTarget) -> bool:
	return other != null and node == other.node and kind == other.kind and (kind != Kind.TREE_PLOT or (cell == other.cell and tree_kind == other.tree_kind))

## Cho biết ô trồng cây có đang ở trạng thái đã mở khóa hay không.
func is_plot_unlocked() -> bool:
	return node is TreePlotDisplay and (node as TreePlotDisplay).plantation != null and (node as TreePlotDisplay).plantation.is_plot_unlocked(cell, tree_kind)

## Kiểm tra node còn tồn tại, hiển thị và đủ điều kiện riêng theo loại.
func valid() -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree() or not node.is_visible_in_tree():
		return false
	match kind:
		Kind.PEN_BOARD:
			return is_instance_valid((node as PenBoard).pen) and (node as PenBoard).pen.is_visible_in_tree()
		Kind.LAND:
			return (node as LandExpansionComponent).sign != null and (node as LandExpansionComponent).sign.visible
		Kind.ANIMAL:
			var animal: AnimalActor = node as AnimalActor
			return not animal.is_dead() and animal.production.definition != null and animal.production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION and animal.production.stored_amount > 0
		Kind.CROP:
			return not (node as Crop).is_retiring() and ((node as Crop).is_mature() or (node as Crop).conditions.affected())
		Kind.FLOWER:
			return (node as FlowerPot).is_mature()
		Kind.TREE:
			return not (node as PerennialTree).removed
		Kind.TREE_PLOT:
			var display: TreePlotDisplay = node as TreePlotDisplay
			var plantation: TreePlantation = display.plantation if display != null else null
			return plantation != null and TreePlantation.valid_cell(cell, tree_kind) and not plantation.trees.has(cell) and plantation.has_ground(cell)
	return true

## Trả thứ tự ưu tiên khi nhiều mục tiêu cùng khả dụng; số nhỏ được chọn trước.
func priority() -> int:
	return 0 if kind in [Kind.MERCHANT, Kind.LAND, Kind.ORDER_BOARD, Kind.PEN_BOARD, Kind.TREE_PLOT_BOARD] else 1 if kind in [Kind.TROUGH,Kind.BEEHIVE] else 2 if kind == Kind.ANIMAL else 3 if kind != Kind.TREE_PLOT else 4

## Khoảng cách tương tác tối đa theo loại mục tiêu.
func reach() -> float:
	return 48.0 if kind == Kind.MERCHANT else 36.0 if kind == Kind.TREE_PLOT else 30.0 if kind == Kind.TROUGH else 20.0 if kind == Kind.CROP else 28.0 if kind == Kind.FLOWER else 32.0

## Tọa độ toàn cục dùng làm điểm tương tác, có xử lý riêng cho cây trồng.
func point() -> Vector2:
	if kind == Kind.TREE_PLOT:
		return (node as TreePlotDisplay).plantation.point_for(cell)
	if kind == Kind.MERCHANT:
		return (node as ShopMerchant).interaction_position()
	if kind == Kind.LAND:
		return (node as LandExpansionComponent).interaction_position()
	if kind == Kind.CROP:
		var farm: FarmingController = player.farming_actions.get_farming_controller()
		var local: Vector2 = farm.farmland.to_local(node.global_position) - Vector2(0, farm.farmland.tile_set.tile_size.y * 0.5)
		return farm.farmland.to_global(farm.farmland.map_to_local(farm.farmland.local_to_map(local)))
	return node.global_position

## Lấy node hình ảnh dùng để kiểm tra điểm nhấp, hoặc null nếu không có.
func sprite() -> Node2D:
	match kind:
		Kind.MERCHANT: return (node as ShopMerchant).interaction_sprite()
		Kind.LAND: return (node as LandExpansionComponent).sign
		Kind.BEEHIVE: return (node as Beehive).sprite
		Kind.TROUGH: return (node as AnimalTrough).sprite
		Kind.ANIMAL: return (node as AnimalActor).sprite
		Kind.CROP: return (node as Crop).sprite
		Kind.FLOWER: return (node as FlowerPot).get_status_sprite()
		Kind.TREE: return (node as PerennialTree).sprite
		Kind.ORDER_BOARD: return (node as OrderBoard).sprite
		Kind.PEN_BOARD: return (node as PenBoard).sprite
		Kind.TREE_PLOT_BOARD: return (node as TreePlotBoard).sprite
	return null

## Kiểm tra hiệu lực, khoảng cách, hướng nhìn tùy chọn và đường nhìn đến mục tiêu.
## Cây trồng còn phải nằm ở ô liền kề đúng hướng; kho có kiểm tra tầm riêng.
func reachable_from(position: Vector2, facing: bool = false) -> bool:
	if not valid():
		return false
	if node is FarmStorageAccess:
		return (node as FarmStorageAccess).can_reach(player)
	if position.distance_to(point()) > reach():
		return false
	if kind == Kind.TREE_PLOT and is_plot_unlocked() and TreePlantation.plot_footprint_rect(point()).has_point(position):
		return false
	var offset: Vector2 = point() - position
	if facing and not offset.is_zero_approx() and offset.normalized().dot(player.animation.facing_vector) < 0.35:
		return false
	var exclusions: Array[RID] = [player.get_rid()]
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(position, point(), 1, exclusions)
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != node:
		return false
	if kind == Kind.CROP:
		var farm: FarmingController = player.farming_actions.get_farming_controller()
		var offset_cell: Vector2i = farm.world_to_cell(point()) - farm.world_to_cell(position)
		var direction: Vector2i = Vector2i(signi(offset_cell.x), 0) if absf(offset.x) > absf(offset.y) else Vector2i(0, signi(offset_cell.y))
		return absi(offset_cell.x) + absi(offset_cell.y) == 1 and offset_cell == direction
	return true

## Tạo nhãn hành động đã dịch dựa trên loại và trạng thái hiện tại của mục tiêu.
func action_text() -> String:
	match kind:
		Kind.TREE_PLOT_BOARD: return tr("Manage tree plots")
		Kind.PEN_BOARD: return tr("Manage pen")
		Kind.ORDER_BOARD: return tr("View orders")
		Kind.MERCHANT:
			if product != null:
				return tr("Collect {product}").format({"product": tr(product.display_name)})
			return (node as ShopMerchant).interaction_action_text()
		Kind.LAND:
			return tr("Reclaim next block ({coins} coins)").format({"coins": GameText.grouped_integer((node as LandExpansionComponent).state.next_price())})
		Kind.TROUGH:
			var trough: AnimalTrough = node as AnimalTrough
			var source: String = "Fill feed ({stock}/{capacity})" if trough.kind == AnimalTrough.Kind.FOOD else "Fill water ({stock}/{capacity})"
			var result: String = tr(source).format({"stock": trough.stock, "capacity": trough.capacity})
			if trough.kind == AnimalTrough.Kind.FOOD:
				result += " · " + tr("Storage feed: {count}").format({"count": player.state.trough_interaction.feed_stock(trough)})
			var reason: String = player.state.trough_interaction.auto_hint(trough)
			return result if reason.is_empty() else result + "\n" + reason
		Kind.ANIMAL:
			var animal: AnimalActor = node as AnimalActor
			return tr("Collect produce") if animal.production.definition != null and animal.production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION and animal.production.stored_amount > 0 else tr("Inspect animal")
		Kind.BEEHIVE: return (node as Beehive).action_text()
		Kind.CROP:
			var farm: FarmingController = player.farming_actions.get_farming_controller()
			var cell: Vector2i = farm.world_to_cell(point())
			var crop: Crop = node as Crop
			var action: String = tr("Clear weeds") if crop.conditions.weeds else tr("Harvest crop") if crop.is_mature() else tr("Use pesticide")
			if crop.is_mature() and crop.conditions.affected():
				action += " · " + tr("Yield: {amount}").format({"amount": farm.harvest_amount(cell)})
			var summary: String = crop.condition_summary()
			if not summary.is_empty():
				action += " · " + summary
			return action + (" · " + tr("Fertile soil: {amount} produce").format({"amount":farm.harvest_amount(cell)}) if farm.fertility.is_fertile(cell) else "")
		Kind.FLOWER: return tr("Harvest flowers")
		Kind.TREE: return (node as PerennialTree).action_text(player.selection.get_selected_item())
		Kind.TREE_PLOT:
			if not is_plot_unlocked():
				return tr("Unlock tree plots")
			return tr("Plant fruit tree") if tree_kind == TreeDefinition.Kind.FRUIT else tr("Plant timber tree")
	return ""
