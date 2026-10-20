class_name SaveSchema
extends RefCounted
## Primitive-only, versioned DTO boundary shared by disk and future HTTP backends.
const VERSION: int = 3
const FlowerLayout = preload("res://scripts/flower_garden_layout.gd")

static func failure(message: String, code: String = "invalid") -> Dictionary:
	return {"ok": false, "code": code, "error": message}

static func number(value: Variant, low: float = 0.0, high: float = 1.0e12, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or float(value) == floor(float(value)))

static func vector(value: Variant, integral: bool = false) -> bool:
	return value is Array and value.size() == 2 and number(value[0], -1000000, 1000000, integral) and number(value[1], -1000000, 1000000, integral)

static func identifier(value: Variant) -> bool:
	return value is String and value.length() > 0 and value.length() <= 100 and value.is_valid_identifier()

static func validate(data: Variant, catalog: SaveCatalog) -> Dictionary:
	if not data is Dictionary:
		return failure("Dữ liệu lưu không phải object.")
	if number(data.get("version"), VERSION + 1, 1000000, true):
		return failure("File được tạo bởi phiên bản game mới hơn.", "future_version")
	# Version 1 predates gardens. Missing gardens initialize as a new map feature;
	# existing inventory, animals, crops and revision remain unchanged.
	if data.get("version") == 1:
		data = data.duplicate(true)
		data.version = 2
		data.flower_gardens = []
	# Version 2 uses a 10x6 garden. Preserve each plant's physical position and
	# lifecycle when inserting the new pots, without modifying the caller's DTO.
	if data.get("version") == 2:
		if not data.get("flower_gardens") is Array:
			return failure("Danh sách vườn hoa cũ không hợp lệ.")
		data = data.duplicate(true)
		for garden: Variant in data.flower_gardens:
			if not garden is Dictionary or not garden.get("flowers") is Array or garden.flowers.size() > 60:
				return failure("Vườn hoa cũ không hợp lệ.")
			for flower: Variant in garden.flowers:
				if not flower is Dictionary or not vector(flower.get("cell"), true):
					return failure("Ô hoa cũ không hợp lệ.")
				var cell: Vector2i = Vector2i(int(flower.cell[0]), int(flower.cell[1]))
				if cell.x < 0 or cell.x >= 10 or cell.y < 0 or cell.y >= 6:
					return failure("Ô hoa cũ ngoài phạm vi.")
				var mapped: Vector2i = FlowerLayout.from_legacy(cell)
				flower.cell = [mapped.x, mapped.y]
		data.version = VERSION
	if data.get("version") != VERSION or data.get("world_id") != "main_world" or not identifier(data.get("profile_id")) or not number(data.get("revision"), 1, 1.0e12, true) or not number(data.get("saved_at")):
		return failure("Header hoặc phiên bản file không hợp lệ.")
	for key: String in ["inventory", "soil", "crops", "animals", "troughs", "pickups", "flower_gardens"]:
		if not data.get(key) is Array or data[key].size() > 100000:
			return failure("Danh sách không hợp lệ: " + key)
	if data.has("animal_pens"):
		if not data.animal_pens is Array or data.animal_pens.size() > 256:
			return failure("Danh sách chuồng không hợp lệ.")
		var pen_ids: Dictionary = {}
		for id: Variant in data.animal_pens:
			if not identifier(id) or pen_ids.has(id):
				return failure("ID chuồng không hợp lệ hoặc bị trùng.")
			pen_ids[id] = true
		for row: Variant in data.animals + data.troughs:
			if not row is Dictionary or not pen_ids.has(row.get("pen")):
				return failure("Vật nuôi/máng không thuộc chuồng đã khai báo.")
	var player: Variant = data.get("player")
	if not player is Dictionary or not vector(player.get("position")) or not ["left", "right", "up", "down"].has(player.get("facing")) or not number(player.get("selected_slot"), 0, 5, true):
		return failure("Người chơi không hợp lệ.")
	if data.inventory.size() < 1 or data.inventory.size() > 256:
		return failure("Số ô túi đồ không hợp lệ.")
	for stack: Variant in data.inventory:
		if not stack is Dictionary or not stack.get("item") is String or not number(stack.get("count"), 0, 32000, true):
			return failure("Ô túi đồ không hợp lệ.")
		if stack.item == "":
			if stack.count != 0:
				return failure("Ô trống có số lượng.")
		elif not catalog.items.has(stack.item) or not number(stack.count, 1, catalog.items[stack.item].get_stack_limit(), true):
			return failure("Vật phẩm hoặc số lượng không hợp lệ.")
	var soil: Dictionary = {}
	for row: Variant in data.soil:
		if not row is Dictionary or not vector(row.get("cell"), true) or not number(row.get("state"), 1, 2, true) or soil.has(str(row.cell)):
			return failure("Ô đất không hợp lệ hoặc bị trùng.")
		soil[str(row.cell)] = true
	var planted: Dictionary = {}
	for row: Variant in data.crops:
		if not row is Dictionary or not vector(row.get("cell"), true) or not catalog.crops.has(row.get("crop")) or not number(row.get("planted_at")) or not number(row.get("matures_at")) or not number(row.get("progress"), 0, 1):
			return failure("Cây trồng không hợp lệ.")
		if row.matures_at <= row.planted_at or row.planted_at > data.saved_at or not soil.has(str(row.cell)) or planted.has(str(row.cell)):
			return failure("Thời gian hoặc ô cây trồng không hợp lệ.")
		planted[str(row.cell)] = true
	var ids: Dictionary = {}
	var piles: Dictionary = {}
	for row: Variant in data.pickups:
		if not row is Dictionary or not _entity(row, ids) or not row.get("pen") is String or not catalog.items.has(row.get("item")) or not number(row.get("amount"), 1, 100000000, true):
			return failure("Vật phẩm trên đất không hợp lệ.")
		piles[row.id] = row
	var owned: Dictionary = {}
	for row: Variant in data.animals:
		if not row is Dictionary or not _entity(row, ids) or not identifier(row.get("pen")) or not catalog.animals.has(row.get("animal")) or not row.get("skin") is String or not catalog.valid_skin(row.animal, row.skin):
			return failure("Vật nuôi không hợp lệ.")
		if not ["left", "right", "up", "down"].has(row.get("facing")) or not number(row.get("age")) or not number(row.get("satiety"), 0, 100) or not number(row.get("hydration"), 0, 100) or not number(row.get("production_progress")) or not number(row.get("production_stock"), 0, 100000000, true) or not row.get("pickup") is String:
			return failure("Tiến trình vật nuôi không hợp lệ.")
		var production: Resource = catalog.animals[row.animal].production
		if production == null:
			if row.production_progress != 0 or row.production_stock != 0 or row.pickup != "":
				return failure("Loài này chưa có sản phẩm.")
		elif row.production_progress >= production.production_seconds:
			return failure("Tiến độ sản xuất vượt chu kỳ.")
		if row.pickup != "":
			if not piles.has(row.pickup) or owned.has(row.pickup) or production == null:
				return failure("Liên kết sản phẩm không hợp lệ.")
			var pile: Dictionary = piles[row.pickup]
			if pile.pen != row.pen or pile.item != String(production.production_item.item_id):
				return failure("Sản phẩm không thuộc vật nuôi.")
			owned[row.pickup] = true
	for row: Variant in data.troughs:
		if not row is Dictionary or not _entity(row, ids) or not identifier(row.get("pen")) or not number(row.get("stock"), 0, 32000, true):
			return failure("Máng ăn/uống không hợp lệ.")
	var gardens: Dictionary = {}
	for garden: Variant in data.flower_gardens:
		if not garden is Dictionary or not identifier(garden.get("id")) or gardens.has(garden.id) or not garden.get("flowers") is Array or garden.flowers.size() > FlowerLayout.CAPACITY:
			return failure("Vườn hoa không hợp lệ hoặc bị trùng.")
		gardens[garden.id] = true
		if garden.has("starter_flowers_added") and not garden.starter_flowers_added is bool:
			return failure("Cờ hoa trồng sẵn không hợp lệ.")
		var cells: Dictionary = {}
		for flower: Variant in garden.flowers:
			if not flower is Dictionary or not vector(flower.get("cell"), true) or not catalog.flowers.has(flower.get("flower")) or not number(flower.get("planted_at")) or not number(flower.get("growth_started_at"), -1) or not number(flower.get("matures_at")) or not number(flower.get("progress"), 0, 1):
				return failure("Hoa trong chậu không hợp lệ.")
			var cell: Vector2i = Vector2i(int(flower.cell[0]), int(flower.cell[1]))
			if cell.x < 0 or cell.x >= FlowerLayout.COLUMNS or cell.y < 0 or cell.y >= FlowerLayout.ROWS or cells.has(cell) or flower.planted_at > data.saved_at:
				return failure("Ô hoặc thời gian gieo hoa không hợp lệ.")
			cells[cell] = true
			if flower.growth_started_at == -1:
				if flower.matures_at != 0 or flower.progress != 0:
					return failure("Hoa chưa tưới không thể có tiến độ.")
			elif flower.growth_started_at < flower.planted_at or flower.growth_started_at > data.saved_at or flower.matures_at <= flower.growth_started_at:
				return failure("Thời gian tưới/chín hoa không hợp lệ.")
	return {"ok": true, "snapshot": data}

static func _entity(row: Dictionary, ids: Dictionary) -> bool:
	if not identifier(row.get("id")) or ids.has(row.id) or not vector(row.get("position")):
		return false
	ids[row.id] = true
	return true
