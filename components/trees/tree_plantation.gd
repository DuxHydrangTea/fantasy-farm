class_name TreePlantation
extends Node
## Quản lý vùng trồng cây ăn quả, cây gỗ và vòng đời các cây trong thế giới.
## Ô lưu ổn định được ánh xạ sang các hàng hiển thị so le. Tiến trình cây
## được chia theo ranh giới thời tiết để tính nhất quán khi chơi và offline.

## Phát khi cây ăn quả giao sản phẩm thành công vào inventory.
@warning_ignore("unused_signal") # FruitTree phát sau khi giao dịch nhận quả đã thành công.
signal harvest_yielded(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent, drop_height: float)
## Vùng ô trồng cây ăn quả.
const FRUIT_REGION: Rect2i = Rect2i(10, 58, 53, 30)
## Vùng ô trồng cây lấy gỗ.
const TIMBER_REGION: Rect2i = Rect2i(66, 58, 52, 30)
## Thế giới chứa cây, đất và các hệ thống liên quan.
var world: FarmWorld
## Ánh xạ ô lưu sang cây hiện có.
var trees: Dictionary[Vector2i, PerennialTree] = {}
## Các định nghĩa cây tra theo mã.
var definitions: Dictionary[StringName, TreeDefinition] = {}
var _placing: bool = false
## Ánh xạ ô công cụ tại vị trí hiển thị sang cây gỗ.
var tool_cells: Dictionary[Vector2i, TimberTree] = {}
## Hiển thị ô trồng cây trên đất.
var plot_display: TreePlotDisplay
## Hai bảng mở rộng đất trồng theo loại cây.
var plot_boards: Dictionary[TreeDefinition.Kind, TreePlotBoard] = {}

func _ready() -> void:
	# Khu đất mới nằm dưới giới hạn camera cũ (1080), mở cả vùng đi lại/click.
	var ground: TileMapLayer = world.farming.ground
	var bottom: Vector2 = ground.to_global(ground.map_to_local(Vector2i(0, TIMBER_REGION.end.y + 3)))
	world.player.camera.limit_bottom = maxi(world.player.camera.limit_bottom, ceili(bottom.y))
	for file: String in ResourceLoader.list_directory("res://trees/definitions"):
		if file.ends_with(".tres"):
			var definition: TreeDefinition = load("res://trees/definitions/" + file) as TreeDefinition
			definitions[definition.tree_id] = definition
	world.farming.time_manager.tick.connect(advance)

## Trả vùng ô tương ứng loại cây.
static func region_for(kind: TreeDefinition.Kind) -> Rect2i:
	return FRUIT_REGION if kind == TreeDefinition.Kind.FRUIT else TIMBER_REGION

## Kiểm tra ô thuộc lưới trồng hợp lệ và chừa khoảng cách tán với biên vùng.
static func valid_cell(cell: Vector2i, kind: TreeDefinition.Kind) -> bool:
	var region: Rect2i = region_for(kind)
	# 48 px giữa hai gốc, lùi tán khỏi đường viền khu đất.
	return region.has_point(cell) and cell.x >= region.position.x + 2 and cell.y >= region.position.y + 3 and cell.x <= region.end.x - 2 and cell.y <= region.end.y - 2 and posmod(cell.x - region.position.x - 2, 3) == 0 and posmod(cell.y - region.position.y - 3, 3) == 0

func _column_spacing(kind: TreeDefinition.Kind) -> float:
	var region: Rect2i = region_for(kind)
	var columns: int = floori(float(region.size.x - 4) / 3.0) + 1
	var old_step: float = world.farming.farmland.tile_set.tile_size.x * 3.0
	# Reserve half a step for alternate rows without pushing the last canopy
	# past the old edge. Whole local pixels keep the pixel art crisp.
	return floorf((columns - 1) * old_step / (columns - 0.5))

## Chuyển ô lưu thành vị trí toàn cục, áp dụng độ lệch hàng so le.
func point_for(cell: Vector2i) -> Vector2:
	var farmland: TileMapLayer = world.farming.farmland
	var local: Vector2 = farmland.map_to_local(cell)
	var kind: TreeDefinition.Kind = TreeDefinition.Kind.FRUIT if FRUIT_REGION.has_point(cell) else TreeDefinition.Kind.TIMBER
	if valid_cell(cell, kind):
		var origin: Vector2i = region_for(kind).position + Vector2i(2, 3)
		var column: int = floori(float(cell.x - origin.x) / 3.0)
		var row: int = floori(float(cell.y - origin.y) / 3.0)
		var spacing: float = _column_spacing(kind)
		local.x += column * (spacing - farmland.tile_set.tile_size.x * 3.0) + posmod(row, 2) * spacing * 0.5
	return farmland.to_global(local)

## Chuyển điểm toàn cục sang ô farmland.
func cell_for(point: Vector2) -> Vector2i:
	return world.farming.world_to_cell(point)

## Tìm ô trồng gần điểm toàn cục theo hàng so le của loại cây.
func planting_cell(point: Vector2, kind: TreeDefinition.Kind) -> Vector2i:
	var origin: Vector2i = region_for(kind).position + Vector2i(2, 3)
	var row: int = roundi(float(cell_for(point).y - origin.y) / 3.0)
	var row_cell: Vector2i = origin + Vector2i(0, row * 3)
	var farmland: TileMapLayer = world.farming.farmland
	var local: Vector2 = farmland.to_local(point)
	var spacing: float = _column_spacing(kind)
	var offset: float = posmod(row, 2) * spacing * 0.5
	var column: int = roundi((local.x - farmland.map_to_local(row_cell).x - offset) / spacing)
	return row_cell + Vector2i(column * 3, 0)

## Kiểm tra điểm nằm trong vùng logic của một trong hai khu trồng.
func in_region(point: Vector2) -> bool:
	var cell: Vector2i = cell_for(point)
	return FRUIT_REGION.has_point(cell) or TIMBER_REGION.has_point(cell)

## Trả hình chữ nhật nhận nhấp chuột quanh tâm ô trồng cây.
static func plot_hit_rect(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(12.0, 10.0), Vector2(24.0, 18.0))

## Trả vùng chân thân cây quanh tâm ô để nhân vật đứng bên ngoài khi mua trồng.
static func plot_footprint_rect(center: Vector2) -> Rect2:
	return Rect2(center + Vector2(-16.0, -10.0), Vector2(32.0, 16.0))

## Kiểm tra mặt đất hợp lệ tại vị trí trồng của ô.
func has_ground(cell: Vector2i) -> bool:
	if world == null or world.farming == null or world.farming.ground == null:
		return false
	var point: Vector2 = point_for(cell)
	var ground: TileMapLayer = world.farming.ground
	return ground.get_cell_source_id(ground.local_to_map(ground.to_local(point))) >= 0

## Kiểm tra ô thuộc loại cây đã được mở khóa hay chưa.
func is_plot_unlocked(cell: Vector2i, kind: TreeDefinition.Kind) -> bool:
	return world != null and world.tree_plot_upgrades != null and TreePlotUpgradeState.allows(world.tree_plot_upgrades.state.capture(), cell, kind)

## Trả danh sách định nghĩa cây hợp lệ theo loại, sắp xếp ổn định cho menu chọn cây.
func definitions_for(kind: TreeDefinition.Kind) -> Array[TreeDefinition]:
	var result: Array[TreeDefinition] = []
	for definition: TreeDefinition in definitions.values():
		if definition != null and definition.is_valid() and definition.kind == kind:
			result.append(definition)
	if kind == TreeDefinition.Kind.FRUIT:
		result.sort_custom(func(a: TreeDefinition, b: TreeDefinition) -> bool:
			return a.price < b.price if a.price != b.price else String(a.tree_id) < String(b.tree_id))
	else:
		var primary: Array[StringName] = [&"oak", &"birch", &"spruce"]
		result.sort_custom(func(a: TreeDefinition, b: TreeDefinition) -> bool:
			var ia: int = primary.find(a.tree_id)
			var ib: int = primary.find(b.tree_id)
			if ia != -1 or ib != -1:
				return ia != -1 and (ib == -1 or ia < ib)
			return String(a.tree_id) < String(b.tree_id))
	return result

func _any_trade_busy() -> bool:
	if is_busy():
		return true
	if world == null:
		return false
	return (world.tree_plot_upgrades != null and world.tree_plot_upgrades.state.is_busy()) \
		or (world.pen_upgrades != null and world.pen_upgrades.state.is_busy()) \
		or (world.tool_upgrade_state != null and world.tool_upgrade_state.is_busy()) \
		or (world.storages != null and world.storages.busy) \
		or (world.wood_market != null and world.wood_market.busy) \
		or (world.workers != null and world.workers.busy)

## Kiểm tra điều kiện mua và trồng cây trực tiếp tại ô đất đã chọn.
func quote_buy(cell: Vector2i, definition: TreeDefinition, wallet: WalletComponent) -> Dictionary:
	if definition == null or not definition.is_valid() or wallet == null:
		return {"ok": false, "error": "This plot is no longer available."}
	if _any_trade_busy():
		return {"ok": false, "error": "A trade is in progress."}
	if not valid_cell(cell, definition.kind) or trees.has(cell) or not is_plot_unlocked(cell, definition.kind) or not has_ground(cell):
		return {"ok": false, "error": "This plot is no longer available."}
	if not can_place(cell, definition, true):
		return {"ok": false, "error": "This plot is blocked."}
	if wallet.balance < definition.price:
		return {"ok": false, "error": "Not enough coins.", "price": definition.price}
	return {"ok": true, "price": definition.price}

## Trừ xu và trồng cây trực tiếp lên ô đất trong một giao dịch nguyên tử.
func purchase_and_plant(cell: Vector2i, definition: TreeDefinition, wallet: WalletComponent, now: float) -> Dictionary:
	var checked: Dictionary = quote_buy(cell, definition, wallet)
	if not checked.ok:
		return checked
	_placing = true
	var previous: int = wallet.balance
	if not wallet.set_balance(previous - definition.price, false):
		_placing = false
		return {"ok": false, "error": "Unable to spend coins."}
	advance(now)
	var tree: PerennialTree = create_tree(cell, definition, now)
	if tree == null:
		wallet.set_balance(previous, false)
		_placing = false
		return {"ok": false, "error": "This plot is no longer available."}
	wallet.changed.emit(wallet.balance)
	_placing = false
	return {"ok": true, "tree": tree, "price": definition.price}

## Kiểm tra định nghĩa, ô hợp lệ đã mở, đất và tùy chọn va chạm tại vị trí trồng.
func can_place(cell: Vector2i, definition: TreeDefinition, check_physics: bool = true) -> bool:
	if definition == null or not definition.is_valid() or not valid_cell(cell, definition.kind) or trees.has(cell) or not is_plot_unlocked(cell, definition.kind):
		return false
	var point: Vector2 = point_for(cell)
	if not has_ground(cell):
		return false
	if check_physics:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(20, 12)
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0, point + Vector2(0, -3))
		query.collision_mask = 7
		if not world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true

## Kiểm tra cây giống trong ô túi và vị trí, tạo cây rồi tiêu một cây giống.
## Trả null nếu điều kiện không đạt.
func plant(cell: Vector2i, bag: InventoryComponent, slot: int, expected: ItemDefinition, now: float) -> PerennialTree:
	if _placing or bag == null or expected == null or bag.get_slot_item(slot) != expected or bag.get_slot_count(slot) < 1 or not expected.crop is TreeDefinition:
		return null
	var definition: TreeDefinition = expected.crop as TreeDefinition
	if not can_place(cell, definition):
		return null
	_placing = true
	var tree: PerennialTree = create_tree(cell, definition, now)
	bag.remove_from_slot(slot, 1)
	_placing = false
	return tree

## Dựng cây theo loại, đăng ký ô chiếm và làm mới cache điều hướng.
## Nơi gọi chịu trách nhiệm kiểm tra tính hợp lệ của dữ liệu trước.
func create_tree(cell: Vector2i, definition: TreeDefinition, now: float) -> PerennialTree:
	var tree: PerennialTree
	if definition.kind == TreeDefinition.Kind.FRUIT:
		tree = FruitTree.new()
	else:
		tree = TimberTree.new()
	tree.name = "%s_%d_%d" % [definition.tree_id, cell.x, cell.y]
	tree.definition = definition
	tree.plantation = self
	tree.cell = cell
	tree.initialize(now)
	tree.position = world.to_local(point_for(cell))
	trees[cell] = tree
	world.add_child(tree)
	if tree is TimberTree:
		tool_cells[world.farming.world_to_cell(tree.global_position)] = tree as TimberTree
	world.farming.set_cell_occupied(cell, true)
	world.player.state.navigation.invalidate_cache()
	if is_instance_valid(plot_display):
		plot_display.queue_redraw()
	return tree

## Bỏ cây khỏi chỉ mục và ô chiếm, đồng thời vô hiệu cache điều hướng.
func remove_tree(tree: PerennialTree) -> void:
	if tree is TimberTree:
		tool_cells.erase(world.farming.world_to_cell(tree.global_position))
	trees.erase(tree.cell)
	world.farming.set_cell_occupied(tree.cell, false)
	world.player.state.navigation.invalidate_cache()
	if is_instance_valid(plot_display):
		plot_display.queue_redraw()

## Tạo đống vật phẩm tại vị trí toàn cục với hiệu ứng nảy ngắn.
func drop_item(item: ItemDefinition, count: int, point: Vector2) -> void:
	var pile: ItemPickup = ItemPickup.create()
	pile.item = item
	pile.amount = count
	pile.position = world.to_local(point)
	world.add_child(pile)
	var tween: Tween = pile.create_tween()
	tween.tween_property(pile.sprite, "position:y", pile.sprite.position.y - 8, 0.12)
	tween.tween_property(pile.sprite, "position:y", pile.sprite.position.y, 0.16)

## Tiến tất cả cây đến mốc thời gian, chia khoảng theo thời tiết và tác động ong.
## Các mẻ quả đã đầy và cây gỗ đã lớn chỉ cập nhật mốc thời gian.
func advance(now: float) -> void:
	# All trees at one cursor share the weather interval. Keep this cache local
	# so hive moves, repairs and weather edits are visible on the next call.
	var weather_intervals: Dictionary = {}
	for tree: PerennialTree in trees.values():
		# A capped fruit batch or fully grown timber cannot gain more growth.
		# Keep the clock advancing so the next harvest starts at the same event.
		if (tree is FruitTree and (tree as FruitTree).has_fruit()) or (tree is TimberTree and not (tree as TimberTree).stump and tree.is_mature()):
			tree.last_at = maxf(tree.last_at, now)
			continue
		var cursor: float = tree.last_at
		# Chia theo mốc thời tiết để load offline và chạy liên tục cho cùng kết quả.
		while cursor < now:
			if not weather_intervals.has(cursor):
				weather_intervals[cursor] = {"boundary": minf(now, world.farming.weather.next_boundary(cursor)) if world.farming.weather != null else now, "rain": world.apiary.raining(cursor) if world.apiary != null else true, "radius": world.apiary.effective_radius(cursor) if world.apiary != null else 0.0}
			var weather: Dictionary = weather_intervals[cursor]
			var boundary: float = float(weather.boundary)
			var rate: float = 1.0
			if not weather.rain:
				for hive: Beehive in world.apiary.hives:
					if hive.global_position.distance_to(tree.global_position) <= float(weather.radius):
						rate = 1.0 / 0.75 # Chu kỳ ngắn hơn 25%, không cộng dồn nhiều tổ.
						break
			tree.refresh(boundary, rate)
			if boundary <= cursor:
				break
			cursor = boundary

## Đồng bộ cây đến now rồi tạo danh sách bản ghi lưu.
func capture(now: float) -> Array:
	advance(now)
	var rows: Array = []
	for tree: PerennialTree in trees.values():
		rows.append(tree.capture())
	return rows

## Xóa các cây hiện tại và giải phóng các ô được đánh dấu chiếm.
func reset() -> void:
	tool_cells.clear()
	for tree: PerennialTree in trees.values().duplicate():
		world.farming.set_cell_occupied(tree.cell, false)
		tree.free()
	trees.clear()

## Thay các cây hiện tại bằng bản ghi đã kiểm tra, rồi tiến đến now.
func restore(rows: Array, now: float) -> void:
	reset()
	for row: Dictionary in rows:
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		var tree: PerennialTree = create_tree(cell, definitions[StringName(row.tree)], float(row.planted_at))
		tree.restore_state(row)
	advance(now)

## Lấy cây gỗ còn hợp lệ tại ô công cụ, hoặc null.
func tool_target(cell: Vector2i) -> TimberTree:
	var tree: TimberTree = tool_cells.get(cell) as TimberTree
	return tree if is_instance_valid(tree) and not tree.removed else null

## Kiểm tra có thể đào gốc hoặc nhổ cây gỗ non tại ô.
func can_dig(cell: Vector2i, bag: InventoryComponent) -> bool:
	var tree: TimberTree = tool_target(cell)
	if tree == null or tree._busy or bag == null:
		return false
	return tree.stump or not tree.is_mature()

## Cho biết đang đặt cây hoặc một cây đang thực hiện giao dịch.
func is_busy() -> bool:
	if _placing:
		return true
	for tree: PerennialTree in trees.values():
		if (tree is TimberTree or tree is FruitTree) and tree._busy:
			return true
	return false

## Tạo hiển thị ô và hai bảng quản lý nâng cấp khu cây.
func setup_plot_upgrades() -> void:
	var display: TreePlotDisplay = TreePlotDisplay.new()
	display.plantation = self
	display.name = "TreePlotMarkers"
	plot_display = display
	world.add_child(display)
	plot_boards.clear()
	for kind: TreeDefinition.Kind in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var board: TreePlotBoard = TreePlotBoard.new()
		board.world = world
		board.kind = kind
		board.name = "FruitPlotBoard" if kind == TreeDefinition.Kind.FRUIT else "TimberPlotBoard"
		var region: Rect2i = region_for(kind)
		var cell: Vector2i = Vector2i(region.position.x + 4, region.end.y + 1)
		board.position = world.to_local(world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell)))
		plot_boards[kind] = board
		world.add_child(board)
