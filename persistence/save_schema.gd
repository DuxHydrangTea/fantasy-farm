class_name SaveSchema
extends RefCounted
## Primitive-only, versioned DTO boundary shared by disk and future HTTP backends.
const VERSION: int = 11
const FlowerLayout = preload("res://scripts/flower_garden_layout.gd")

static func failure(message: String, code: String = "invalid", values: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "error": message, "error_values": values}

static func number(value: Variant, low: float = 0.0, high: float = 1.0e12, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or float(value) == floor(float(value)))

static func vector(value: Variant, integral: bool = false) -> bool:
	return value is Array and value.size() == 2 and number(value[0], -1000000, 1000000, integral) and number(value[1], -1000000, 1000000, integral)

static func identifier(value: Variant) -> bool:
	return value is String and value.length() > 0 and value.length() <= 100 and value.is_valid_identifier()

# BIÊN DỮ LIỆU — migrate tuần tự rồi mới kiểm tra schema hiện tại.
# Mỗi phiên bản bổ sung một thay đổi khác nhau (vườn, layout, tiền, sức chứa túi), nên không
# được chỉ gán version=VERSION để bỏ qua các bước. Đổi nhãn không biến dữ liệu cũ thành dữ liệu mới.
# duplicate(true) trước khi migrate để caller/backup vẫn giữ nguyên bản đầu vào nếu kiểm tra thất bại.
# Các Resource chỉ được tìm bằng ID trong catalog cho phép; không load đường dẫn tùy ý từ file.
# Nếu bỏ validation, dữ liệu lỗi/không tương thích có thể đi vào scene rồi làm mất trạng thái đang chơi.
static func validate(data: Variant, catalog: SaveCatalog) -> Dictionary:
	if not data is Dictionary:
		return failure("Save data is not an object.")
	if number(data.get("version"), VERSION + 1, 1000000, true):
		return failure("This save was created by a newer game version.", "future_version")
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
			return failure("Invalid legacy flower garden list.")
		data = data.duplicate(true)
		for garden: Variant in data.flower_gardens:
			if not garden is Dictionary or not garden.get("flowers") is Array or garden.flowers.size() > 60:
				return failure("Invalid legacy flower garden.")
			for flower: Variant in garden.flowers:
				if not flower is Dictionary or not vector(flower.get("cell"), true):
					return failure("Invalid legacy flower cell.")
				var cell: Vector2i = Vector2i(int(flower.cell[0]), int(flower.cell[1]))
				if cell.x < 0 or cell.x >= 10 or cell.y < 0 or cell.y >= 6:
					return failure("Legacy flower cell is out of bounds.")
				var mapped: Vector2i = FlowerLayout.from_legacy(cell)
				flower.cell = [mapped.x, mapped.y]
		data.version = 3
	# Version 3 predates currency. One-time grant, never on subsequent loads.
	if data.get("version") == 3:
		data = data.duplicate(true)
		data.version = 4
		data.coins = WalletComponent.STARTING_COINS
	# The old 24-slot bag cannot hold the current seed/feed/produce catalog.
	# Append independent empty slots; keep item stacks, hotbar and currency intact.
	# Also accept a 24-slot snapshot written by an old, still-running player
	# instance after scripts reload; a restart will instantiate the new bag size.
	# Chỉ thêm ô rỗng phía sau 24 ô cũ để giữ vị trí hotbar, item/count, xu và lịch sử tiến trình.
	# Cần nhận cả snapshot mang version hiện tại nhưng còn 24 ô: game đang chạy bản cũ có thể
	# hot-reload script rồi autosave trước khi được khởi động lại. Không xử lý hình dạng cũ này
	# thì lần mở sau bag 64 ô sẽ không khớp save, khiến tải bị từ chối.
	# Không tự lấp lại các slot đã tồn tại: làm vậy có thể ghi đè đồ người chơi hoặc cấp thêm đồ.
	if data.get("version") == 4 or (data.get("version") in [5, 6, 7, 8, 9, 10, VERSION] and data.get("inventory") is Array and data.inventory.size() == InventoryComponent.LEGACY_SLOT_COUNT):
		if not data.get("inventory") is Array:
			return failure("Invalid legacy inventory.")
		data = data.duplicate(true)
		if data.inventory.size() == InventoryComponent.LEGACY_SLOT_COUNT:
			while data.inventory.size() < InventoryComponent.DEFAULT_SLOT_COUNT:
				data.inventory.append({"item": "", "count": 0})
		if data.version == 4:
			data.version = 5
	# Land ownership is new in v6. Preserve every previously tilled/planted cell
	# by opening the contiguous columns needed to reach it, without charging coins.
	# Never reset a legacy farm (including fully planted debug saves).
	if data.get("version") == 5:
		if not data.get("soil") is Array:
			return failure("Invalid legacy soil list.")
		data = data.duplicate(true)
		var columns: int = 1
		for row: Variant in data.soil:
			if not row is Dictionary or not vector(row.get("cell"), true):
				return failure("Invalid legacy soil cell.")
			var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
			if LandExpansionState.REGION.has_point(cell):
				columns = maxi(columns, LandExpansionState.REGION.end.x - cell.x)
		data.land_columns = columns
		data.version = 6
	if data.get("version") == 6:
		if not data.get("crops") is Array or not data.get("animals") is Array:
			return failure("Invalid legacy booster state.")
		data = data.duplicate(true)
		for row: Variant in data.crops:
			if not row is Dictionary:
				return failure("Invalid crop.")
			row.fertilized = false
		for row: Variant in data.animals:
			if not row is Dictionary:
				return failure("Invalid animal.")
			row.juvenile_tonic_used = false
			row.tonic_pending = false
		data.version = 7
	if data.get("version") == 7:
		if not data.get("troughs") is Array:
			return failure("Invalid legacy trough list.")
		data = data.duplicate(true)
		for row: Variant in data.troughs:
			if not row is Dictionary:
				return failure("Invalid feed or water trough.")
			row.feed_reserve = 0
		data.version = 8
	if data.get("version") == 8:
		if not data.get("crops") is Array:
			return failure("Invalid legacy crop list.")
		data = data.duplicate(true)
		data.beehives = []
		for row: Variant in data.crops:
			if not row is Dictionary:
				return failure("Invalid crop.")
			row.pollination_reduction = 0.0
		data.version = 9
	if data.get("version") == 9:
		if not data.get("soil") is Array:
			return failure("Invalid legacy soil list.")
		data = data.duplicate(true)
		data.weather = WeatherSchedule.new().capture()
		for row: Variant in data.soil:
			if not row is Dictionary:
				return failure("Invalid soil moisture.")
			row.moisture = FarmingController.SOIL_MOISTURE_SECONDS if row.get("state") == 2 else 0.0
		data.version = 10
	if data.get("version") == 10:
		data = data.duplicate(true)
		data.trees = []
		data.version = VERSION
	if data.get("version") != VERSION or data.get("world_id") != "main_world" or not identifier(data.get("profile_id")) or not number(data.get("revision"), 1, 1.0e12, true) or not number(data.get("saved_at")):
		return failure("Invalid save header or version.")
	if not TreeSaveSchema.valid(data.get("trees"), catalog, float(data.saved_at)):
		return failure("Invalid perennial tree state.")
	var weather: Variant = data.get("weather")
	if not weather is Dictionary or not number(weather.get("seed"), 0, 2147483647, true) or not weather.get("changes") is Array or weather.changes.size() > 1024:
		return failure("Invalid weather history.")
	var previous: float = -1.0
	for entry: Variant in weather.changes:
		if not entry is Dictionary or not number(entry.get("at"), 0, data.saved_at) or float(entry.at) < previous or not number(entry.get("weather"), 0, 3, true):
			return failure("Invalid weather history.")
		previous = float(entry.at)
	if not number(data.get("land_columns"), 1, LandExpansionState.REGION.size.x, true):
		return failure("Invalid unlocked farmland columns.")
	if not number(data.get("coins"), 0, WalletComponent.MAX_COINS, true):
		return failure("Invalid coin balance.")
	for key: String in ["inventory", "soil", "crops", "animals", "troughs", "pickups", "flower_gardens", "beehives"]:
		if not data.get(key) is Array or data[key].size() > 100000:
			return failure("Invalid list: {list}", "invalid", {"list": key})
	if data.has("animal_pens"):
		if not data.animal_pens is Array or data.animal_pens.size() > 256:
			return failure("Invalid pen list.")
		var pen_ids: Dictionary = {}
		for id: Variant in data.animal_pens:
			if not identifier(id) or pen_ids.has(id):
				return failure("Invalid or duplicate pen ID.")
			pen_ids[id] = true
		for row: Variant in data.animals + data.troughs:
			if not row is Dictionary or not pen_ids.has(row.get("pen")):
				return failure("An animal or trough does not belong to a declared pen.")
	var player: Variant = data.get("player")
	if not player is Dictionary or not vector(player.get("position")) or not ["left", "right", "up", "down"].has(player.get("facing")) or not number(player.get("selected_slot"), 0, 5, true):
		return failure("Invalid player data.")
	if data.inventory.size() < 1 or data.inventory.size() > 256:
		return failure("Invalid inventory slot count.")
	for stack: Variant in data.inventory:
		if not stack is Dictionary or not stack.get("item") is String or not number(stack.get("count"), 0, 32000, true):
			return failure("Invalid inventory slot.")
		if stack.item == "":
			if stack.count != 0:
				return failure("An empty slot has a nonzero count.")
		elif not catalog.items.has(stack.item) or not number(stack.count, 1, catalog.items[stack.item].get_stack_limit(), true):
			return failure("Invalid item or count.")
	var soil: Dictionary = {}
	for row: Variant in data.soil:
		if not row is Dictionary or not vector(row.get("cell"), true) or not number(row.get("state"), 1, 2, true) or soil.has(str(row.cell)):
			return failure("Invalid or duplicate soil cell.")
		if not LandExpansionState.cell_is_open(Vector2i(int(row.cell[0]), int(row.cell[1])), int(data.land_columns)):
			return failure("Saved soil is on locked farmland.")
		if not number(row.get("moisture"), 0, FarmingController.SOIL_MOISTURE_SECONDS) or (row.state == 1 and row.moisture != 0) or (row.state == 2 and row.moisture <= 0):
			return failure("Invalid soil moisture.")
		soil[str(row.cell)] = true
	var planted: Dictionary = {}
	for row: Variant in data.crops:
		if not row is Dictionary or not vector(row.get("cell"), true) or not catalog.crops.has(row.get("crop")) or not number(row.get("planted_at")) or not number(row.get("matures_at")) or not number(row.get("progress"), 0, 1):
			return failure("Invalid crop.")
		if not number(row.get("pollination_reduction")):
			return failure("Invalid crop pollination state.")
		if not row.get("fertilized") is bool:
			return failure("Invalid crop fertilizer state.")
		if row.matures_at <= row.planted_at or row.planted_at > data.saved_at or not soil.has(str(row.cell)) or planted.has(str(row.cell)):
			return failure("Invalid crop time or cell.")
		planted[str(row.cell)] = true
	var ids: Dictionary = {}
	var piles: Dictionary = {}
	for row: Variant in data.pickups:
		if not row is Dictionary or not _entity(row, ids) or not row.get("pen") is String or not catalog.items.has(row.get("item")) or not number(row.get("amount"), 1, 100000000, true):
			return failure("Invalid ground item.")
		piles[row.id] = row
	var owned: Dictionary = {}
	for row: Variant in data.animals:
		if not row is Dictionary or not _entity(row, ids) or not identifier(row.get("pen")) or not catalog.animals.has(row.get("animal")) or not row.get("skin") is String or not catalog.valid_skin(row.animal, row.skin):
			return failure("Invalid animal.")
		if not ["left", "right", "up", "down"].has(row.get("facing")) or not number(row.get("age")) or not number(row.get("satiety"), 0, 100) or not number(row.get("hydration"), 0, 100) or not number(row.get("production_progress")) or not number(row.get("production_stock"), 0, 100000000, true) or not row.get("pickup") is String:
			return failure("Invalid animal progress.")
		if not row.get("juvenile_tonic_used") is bool or not row.get("tonic_pending") is bool:
			return failure("Invalid animal tonic state.")
		var maturity: float = catalog.animals[row.animal].maturity_seconds * (0.5 if row.juvenile_tonic_used else 1.0)
		if row.tonic_pending and row.age < maturity:
			return failure("A juvenile cannot have a production tonic.")
		var production: Resource = catalog.animals[row.animal].production
		if production == null:
			if row.production_progress != 0 or row.production_stock != 0 or row.pickup != "" or row.tonic_pending:
				return failure("This species has no produce configured.")
		elif row.production_progress >= production.production_seconds:
			return failure("Production progress exceeds the cycle.")
		if row.pickup != "":
			if not piles.has(row.pickup) or owned.has(row.pickup) or production == null:
				return failure("Invalid produce link.")
			var pile: Dictionary = piles[row.pickup]
			if pile.pen != row.pen or pile.item != String(production.production_item.item_id):
				return failure("Produce does not belong to the animal.")
			owned[row.pickup] = true
	for row: Variant in data.troughs:
		if not row is Dictionary or not _entity(row, ids) or not identifier(row.get("pen")) or not number(row.get("stock"), 0, 32000, true) or not number(row.get("feed_reserve"), 0, 32000, true):
			return failure("Invalid feed or water trough.")
	var honey_rules: BeehiveDefinition = preload("res://resources/bees/beehive.tres")
	for row: Variant in data.beehives:
		if not row is Dictionary or not _entity(row,ids) or not number(row.get("work"),0,honey_rules.cycle_seconds) or not row.get("contributions") is Dictionary or not row.get("ready_item") is String:
			return failure("Invalid beehive state.")
		var total: float = 0.0
		var production: BeehiveProductionComponent = BeehiveProductionComponent.new()
		production.definition = honey_rules
		for key: Variant in row.contributions:
			if not key is String or (key != "sunflower" and not catalog.flowers.has(key)) or not number(row.contributions[key],0,row.work):
				return failure("Invalid honey pollen contribution.")
			total += float(row.contributions[key])
		if total > float(row.work) + 0.000001:
			return failure("Invalid honey pollen contribution.")
		production.contributions = row.contributions
		var full: bool = float(row.work) >= honey_rules.cycle_seconds
		if (full and row.ready_item != String(production.expected_item().item_id)) or (not full and row.ready_item != ""):
			return failure("Invalid stored honey.")
	var gardens: Dictionary = {}
	for garden: Variant in data.flower_gardens:
		if not garden is Dictionary or not identifier(garden.get("id")) or gardens.has(garden.id) or not garden.get("flowers") is Array or garden.flowers.size() > FlowerLayout.CAPACITY:
			return failure("Invalid or duplicate flower garden.")
		gardens[garden.id] = true
		if garden.has("starter_flowers_added") and not garden.starter_flowers_added is bool:
			return failure("Invalid preplanted flower flag.")
		var cells: Dictionary = {}
		for flower: Variant in garden.flowers:
			if not flower is Dictionary or not vector(flower.get("cell"), true) or not catalog.flowers.has(flower.get("flower")) or not number(flower.get("planted_at")) or not number(flower.get("growth_started_at"), -1) or not number(flower.get("matures_at")) or not number(flower.get("progress"), 0, 1):
				return failure("Invalid potted flower.")
			var cell: Vector2i = Vector2i(int(flower.cell[0]), int(flower.cell[1]))
			if cell.x < 0 or cell.x >= FlowerLayout.COLUMNS or cell.y < 0 or cell.y >= FlowerLayout.ROWS or cells.has(cell) or flower.planted_at > data.saved_at:
				return failure("Invalid flower cell or planting time.")
			cells[cell] = true
			if flower.growth_started_at == -1:
				if flower.matures_at != 0 or flower.progress != 0:
					return failure("An unwatered flower cannot have progress.")
			elif flower.growth_started_at < flower.planted_at or flower.growth_started_at > data.saved_at or flower.matures_at <= flower.growth_started_at:
				return failure("Invalid flower watering or maturity time.")
	return {"ok": true, "snapshot": data}

static func _entity(row: Dictionary, ids: Dictionary) -> bool:
	if not identifier(row.get("id")) or ids.has(row.id) or not vector(row.get("position")):
		return false
	ids[row.id] = true
	return true
