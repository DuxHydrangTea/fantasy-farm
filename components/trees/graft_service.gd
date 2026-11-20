class_name GraftService
extends RefCounted
## Điều phối chọn hướng ghép và thu hoạch thủ công cho cây ăn quả.
## Chốt thời gian công nhân trước khi thay đổi hoặc thu hoạch cây.

## Phát khi lựa chọn ghép hoặc thu hoạch được xử lý.
signal changed
## Mã sáp ghép dùng khi đổi hướng đã chọn.
const WAX: StringName = &"grafting_wax"
## Thế giới chứa cây, người chơi và các giao dịch liên quan.
var world: FarmWorld
## Cho biết dịch vụ đang xử lý thao tác.
var busy: bool = false

## Trả thông báo lỗi nếu hệ thống bận, cây không hợp lệ, ngoài tầm hoặc chưa lớn.
## Trả chuỗi rỗng khi có thể thao tác.
func access_error(tree: FruitTree) -> String:
	if busy or world == null or not world.tool_upgrades.profile_ready or world.workers.busy or world.storages.busy or world.wood_market.busy or world.cooking.busy or world.tool_upgrade_state.is_busy():
		return "Grafting is unavailable."
	if not is_instance_valid(tree) or tree.removed or not world.is_ancestor_of(tree) or tree._busy:
		return "This tree is unavailable."
	if not InteractionTarget.new(tree, InteractionTarget.Kind.TREE, world.player).reachable_from(world.player.global_position):
		return "Move closer to this tree."
	if not tree.is_mature():
		return "Wait until the tree is mature."
	return ""

## Kiểm tra hướng ghép và tính lượng sáp cần cùng revision hiện tại của cây.
## Lần chọn đầu miễn phí; đổi lựa chọn sau đó cần một sáp.
func quote(tree: FruitTree, direction: int) -> Dictionary:
	var error: String = access_error(tree)
	if not error.is_empty():
		return {"ok": false, "error": error}
	if direction not in [FruitTree.Graft.YIELD, FruitTree.Graft.QUALITY] or (direction == FruitTree.Graft.QUALITY and tree.definition.star_harvest_item == null):
		return {"ok": false, "error": "Invalid graft direction."}
	var planned: int = tree.pending_graft if tree.pending_graft != FruitTree.Graft.NONE else tree.active_graft
	if direction == planned:
		return {"ok": false, "error": "This graft direction is already selected."}
	var cost: int = 0 if tree.active_graft == FruitTree.Graft.NONE and tree.pending_graft == FruitTree.Graft.NONE else 1
	return {"ok": world.player.selection.inventory.count_item(WAX) >= cost, "error": "Not enough Grafting Wax in your bag." if world.player.selection.inventory.count_item(WAX) < cost else "", "wax": cost, "revision": tree.graft_revision}

## Chọn hướng ghép chờ áp dụng sau khi chốt công nhân và kiểm tra revision.
## Trả chuỗi rỗng khi thành công, hoặc thông báo lỗi.
func choose(tree: FruitTree, direction: int, expected_revision: int) -> String:
	var error: String = access_error(tree)
	if not error.is_empty():
		return error
	world.workers.settle(world.farming.time_manager.now())
	var offer: Dictionary = quote(tree, direction)
	if not offer.ok:
		return offer.error
	if tree.graft_revision != expected_revision:
		return "The tree changed. Review its current crop and try again."
	_lock(true)
	tree._busy = true
	var bag: InventoryComponent = world.player.selection.inventory
	if offer.wax > 0:
		bag.remove(WAX, 1, false)
	tree.pending_graft = direction
	tree.graft_revision += 1
	if offer.wax > 0:
		bag.changed.emit()
	changed.emit()
	tree._busy = false
	_lock(false)
	return ""

## Thu hoạch vào túi sau khi đồng bộ và kiểm tra lại quyền truy cập.
## Trả chuỗi rỗng khi thành công, hoặc lý do không thu được.
func collect(tree: FruitTree) -> String:
	var error: String = access_error(tree)
	if not error.is_empty():
		return error
	world.workers.settle(world.farming.time_manager.now())
	error = access_error(tree)
	if not error.is_empty():
		return error
	_lock(true)
	var collected: bool = tree.harvest(world.player.selection.inventory)
	changed.emit()
	_lock(false)
	return "" if collected else "Fruit is not ready or your bag cannot hold the whole crop."

func _lock(value: bool) -> void:
	busy = value
	world.workers.busy = value
	world.storages.busy = value

## Ghi lại những thay đổi do người chơi thực hiện trong một profile đang chạy.
func save_changes() -> void:
	if not is_instance_valid(world) or world.is_queued_for_deletion():
		return
	var manager: GameSaveManager = world.get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

## Đếm số đơn hiện hành có yêu cầu sản phẩm thu hoạch thường của cây.
func order_demand(tree: FruitTree) -> int:
	var count: int = 0
	for row: Dictionary in world.orders.service.capture().slots:
		if not row.has("serial"):
			continue
		var entry: OrderDefinition = world.orders.service.definition(int(row.serial))
		if entry != null:
			for item: ItemDefinition in entry.items:
				if item.matches(tree.definition.harvest_item):
					count += 1
					break
	return count

## Đếm công thức nấu có sử dụng vật phẩm thu hoạch chất lượng sao của cây.
func kitchen_demand(tree: FruitTree) -> int:
	var count: int = 0
	for recipe: CookingRecipe in ChefCooking.RECIPES:
		if recipe.ingredients.has(tree.definition.star_harvest_item):
			count += 1
	return count
