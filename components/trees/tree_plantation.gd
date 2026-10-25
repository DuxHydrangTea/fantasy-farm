class_name TreePlantation
extends Node
## Stable saved cells map to staggered rows in both tree regions.
@warning_ignore("unused_signal") # FruitTree phát sau khi giao dịch nhận quả đã thành công.
signal harvest_yielded(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent, drop_height: float)
const FRUIT_REGION: Rect2i = Rect2i(10, 58, 53, 30)
const TIMBER_REGION: Rect2i = Rect2i(66, 58, 52, 30)
var world: FarmWorld
var trees: Dictionary[Vector2i, PerennialTree] = {}
var definitions: Dictionary[StringName, TreeDefinition] = {}
var _placing: bool = false
var tool_cells: Dictionary[Vector2i, TimberTree] = {}

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

static func region_for(kind: TreeDefinition.Kind) -> Rect2i:
	return FRUIT_REGION if kind == TreeDefinition.Kind.FRUIT else TIMBER_REGION

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

func cell_for(point: Vector2) -> Vector2i:
	return world.farming.world_to_cell(point)

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

func in_region(point: Vector2) -> bool:
	var cell: Vector2i = cell_for(point)
	return FRUIT_REGION.has_point(cell) or TIMBER_REGION.has_point(cell)

func can_place(cell: Vector2i, definition: TreeDefinition, check_physics: bool = true) -> bool:
	if definition == null or not definition.is_valid() or not valid_cell(cell, definition.kind) or trees.has(cell):
		return false
	var point: Vector2 = point_for(cell)
	var ground: TileMapLayer = world.farming.ground
	if ground.get_cell_source_id(ground.local_to_map(ground.to_local(point))) < 0:
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
	return tree

func remove_tree(tree: PerennialTree) -> void:
	if tree is TimberTree:
		tool_cells.erase(world.farming.world_to_cell(tree.global_position))
	trees.erase(tree.cell)
	world.farming.set_cell_occupied(tree.cell, false)
	world.player.state.navigation.invalidate_cache()

func drop_item(item: ItemDefinition, count: int, point: Vector2) -> void:
	var pile: ItemPickup = ItemPickup.create()
	pile.item = item
	pile.amount = count
	pile.position = world.to_local(point)
	world.add_child(pile)
	var tween: Tween = pile.create_tween()
	tween.tween_property(pile.sprite, "position:y", pile.sprite.position.y - 8, 0.12)
	tween.tween_property(pile.sprite, "position:y", pile.sprite.position.y, 0.16)

func advance(now: float) -> void:
	for tree: PerennialTree in trees.values():
		var cursor: float = tree.last_at
		# Chia theo mốc thời tiết để load offline và chạy liên tục cho cùng kết quả.
		while cursor < now:
			var boundary: float = minf(now, world.farming.weather.next_boundary(cursor)) if world.farming.weather != null else now
			var rate: float = 1.0
			if world.apiary != null and not world.apiary.raining(cursor):
				for hive: Beehive in world.apiary.hives:
					if hive.global_position.distance_to(tree.global_position) <= world.apiary.effective_radius(cursor):
						rate = 1.0 / 0.75 # Chu kỳ ngắn hơn 25%, không cộng dồn nhiều tổ.
						break
			tree.refresh(boundary, rate)
			if boundary <= cursor:
				break
			cursor = boundary

func capture(now: float) -> Array:
	advance(now)
	var rows: Array = []
	for tree: PerennialTree in trees.values():
		rows.append(tree.capture())
	return rows

func reset() -> void:
	tool_cells.clear()
	for tree: PerennialTree in trees.values().duplicate():
		world.farming.set_cell_occupied(tree.cell, false)
		tree.free()
	trees.clear()

func restore(rows: Array, now: float) -> void:
	reset()
	for row: Dictionary in rows:
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		var tree: PerennialTree = create_tree(cell, definitions[StringName(row.tree)], float(row.planted_at))
		tree.restore_state(row)
	advance(now)

func tool_target(cell: Vector2i) -> TimberTree:
	var tree: TimberTree = tool_cells.get(cell) as TimberTree
	return tree if is_instance_valid(tree) and not tree.removed else null

func can_dig(cell: Vector2i, bag: InventoryComponent) -> bool:
	var tree: TimberTree = tool_target(cell)
	if tree == null or tree._busy or bag == null:
		return false
	return tree.stump or (not tree.is_mature() and bag.capacity_for(tree.definition.planting_item()) > 0)

func is_busy() -> bool:
	if _placing:
		return true
	for tree: PerennialTree in trees.values():
		if (tree is TimberTree or tree is FruitTree) and tree._busy:
			return true
	return false
