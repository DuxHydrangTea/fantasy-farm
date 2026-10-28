class_name HoneyGardenSystem
extends Node
## Owns the fixed garden layout, atomic legacy conversion, repairs and journal.
signal changed
const Layout = preload("res://scripts/flower_garden_layout.gd")
const CENTERS: Array[Vector2i] = [Vector2i(1,2), Vector2i(1,6), Vector2i(8,2)]
# Physical hives sit on the path below the beds; CENTERS only defines flower recipes.
const HIVE_POSITIONS: Array[Vector2] = [Vector2(64, 280), Vector2(192, 280), Vector2(320, 280)]
var world: FarmWorld
var migrated: bool = false
var discoveries: Array[String] = []
var busy: bool = false
var notice: String = ""
var _elapsed: float = 0.0
var _notice_label: Label

static func fresh() -> Dictionary:
	return {"migrated":false, "discoveries":[]}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2 or not data.get("migrated") is bool or not data.get("discoveries") is Array:
		return false
	var seen: Dictionary = {}
	for id: Variant in data.discoveries:
		if not id is String or id not in HoneyComboCatalog.IDS or seen.has(id):
			return false
		seen[id] = true
	return true

func _ready() -> void:
	world.cooking.crafted.connect(_crafted)
	if garden() != null:
		_notice_label = Label.new()
		_notice_label.position = Vector2(8,224)
		_notice_label.size = Vector2(368,40)
		_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notice_label.add_theme_font_size_override("font_size",9)
		_notice_label.add_theme_color_override("font_color",Color.WHITE)
		_notice_label.add_theme_color_override("font_outline_color",Color.BLACK)
		_notice_label.add_theme_constant_override("outline_size",2)
		_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		garden().add_child(_notice_label)

func garden() -> FlowerGarden:
	return world.apiary.gardens[0] if not world.apiary.gardens.is_empty() else null

func inside(hive: Beehive) -> bool:
	var area: FlowerGarden = garden()
	return area != null and ((hive.garden_slot >= 0 and hive.garden_id == String(area.persistent_id)) or Rect2(Vector2.ZERO, FlowerGarden.SIZE).has_point(area.to_local(hive.global_position)))

func center_point(slot: int) -> Vector2:
	return garden().to_global(HIVE_POSITIONS[slot])

func owner_slot(cell: Vector2i) -> int:
	for slot: int in range(3):
		var offset: Vector2i = cell - CENTERS[slot]
		if offset != Vector2i.ZERO and absi(offset.x) <= 1 and absi(offset.y) <= 1:
			return slot
	return -1

func prepare_waiting() -> void:
	# This runs before catch-up too: draining a batch must never start another.
	for hive: Beehive in world.apiary.hives:
		hive.production.pause_new_batches = not migrated and inside(hive)

func capture() -> Dictionary:
	return {"migrated":migrated, "discoveries":discoveries.duplicate()}

func restore(data: Dictionary) -> void:
	migrated = data.migrated
	discoveries.assign(data.discoveries)
	notice = ""
	_release_centers()

func _release_centers() -> void:
	if garden() == null:
		return
	for cell: Vector2i in CENTERS:
		var pot: FlowerPot = garden().pots[cell]
		pot.reserved = false
		pot.visible = true
		pot.collision_layer = 1

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		if not migrated:
			try_migrate()
		if _notice_label != null:
			_notice_label.text = tr(notice)
			_notice_label.visible = not notice.is_empty()

func try_migrate() -> bool:
	if migrated:
		return true
	if busy or garden() == null or garden().starter_content_locked or not world.tool_upgrades.profile_ready or world.workers.busy or world.storages.busy or world.apiary.loading or world.apiary._advancing or world.apiary._placing or world.cooking.busy or world.wood_market.busy or world.tool_upgrade_state.is_busy():
		return false
	prepare_waiting()
	world.apiary.sync()
	var legacy: Array[Beehive] = []
	for hive: Beehive in world.apiary.hives:
		if inside(hive):
			legacy.append(hive)
	legacy.sort_custom(func(a: Beehive,b: Beehive) -> bool: return String(a.persistent_id) < String(b.persistent_id))
	for hive: Beehive in legacy:
		if hive.production.work > 0.0 or hive.production.ready_item != null:
			notice = "Garden conversion waiting: collect every existing garden honey batch first."
			return false
	for slot: int in range(HIVE_POSITIONS.size()):
		var point: Vector2 = center_point(slot)
		if not world.apiary.placement_error(point, -1, true).is_empty() or world.farming.get_crop(world.farming.world_to_cell(point)) != null:
			notice = "This space is blocked."
			return false
	var extra: int = maxi(0,legacy.size()-3)
	var bag: InventoryComponent = world.player.selection.inventory
	if bag.capacity_for(world.apiary.definition.hive_item) < extra:
		notice = "Garden conversion waiting: free bag space for surplus beehives."
		return false
	# All prerequisites have passed. No add-and-discard or partial conversion.
	_lock(true)
	world.apiary.loading = true
	for hive: Beehive in legacy:
		world.farming.set_cell_occupied(world.farming.world_to_cell(hive.global_position),false)
	for slot: int in range(3):
		var retained: bool = slot < legacy.size()
		var hive: Beehive = legacy[slot] if retained else world.apiary.create_hive(center_point(slot),StringName("garden_hive_%d_" % slot + Crypto.new().generate_random_bytes(8).hex_encode()))
		hive.global_position = center_point(slot)
		hive.garden_id = String(garden().persistent_id)
		hive.garden_slot = slot
		hive.repaired = retained or slot == 1
		hive.production.garden_mode = true
		hive.production.pause_new_batches = false
		hive.production.legacy_batch = false
		hive.production.contributions.clear()
		hive.refresh_visual()
		world.farming.set_cell_occupied(world.farming.world_to_cell(hive.global_position),true)
	for index: int in range(3,legacy.size()):
		world.apiary.hives.erase(legacy[index])
		legacy[index].free()
	migrated = true
	_release_centers()
	if extra > 0:
		bag.add(world.apiary.definition.hive_item,extra,0,false)
	world.apiary.loading = false
	world.apiary.advance(world.apiary.last_at)
	notice = ""
	world.player.state.navigation.invalidate_cache()
	if extra > 0:
		bag.changed.emit()
	changed.emit()
	_lock(false)
	return true

func recipe_for(hive: Beehive, sources: Array[Dictionary], timestamp: float) -> String:
	var blooms: Dictionary = {}
	for source: Dictionary in sources:
		if source.get("garden", "") == hive.garden_id and owner_slot(source.get("cell",Vector2i(-99,-99))) == hive.garden_slot and float(source.ready_at) <= timestamp + 0.000001:
			blooms[source.cell - CENTERS[hive.garden_slot]] = source.type
	return HoneyComboCatalog.resolve(blooms)

func access_error(hive: Beehive) -> String:
	if busy or not world.tool_upgrades.profile_ready or world.workers.busy or world.storages.busy or world.apiary.loading or world.apiary._advancing or world.cooking.busy or world.wood_market.busy or world.tool_upgrade_state.is_busy():
		return "Bee journal is unavailable."
	if not is_instance_valid(hive) or not world.apiary.hives.has(hive) or not InteractionTarget.new(hive,InteractionTarget.Kind.BEEHIVE,world.player).reachable_from(world.player.global_position):
		return "Move closer to the hive."
	return ""

func repair(hive: Beehive) -> String:
	var error: String = access_error(hive)
	if not error.is_empty():
		return error
	world.workers.settle(world.farming.time_manager.now())
	world.apiary.sync()
	error = access_error(hive)
	if not error.is_empty():
		return error
	if hive.garden_slot < 0 or hive.repaired:
		return "This hive does not need repair."
	if world.tool_upgrades.wood_owned() < 15 or world.player.wallet.balance < 500:
		return "Repair needs 15 ordinary wood and 500 coins."
	_lock(true)
	var remaining: int = 15
	for inventory: InventoryComponent in world.tool_upgrades.wood_sources():
		var amount: int = mini(remaining,inventory.count_item(&"wood",0))
		inventory.consume(&"wood",amount,ItemQuality.exact(0),false)
		remaining -= amount
	world.player.wallet.set_balance(world.player.wallet.balance-500,false)
	hive.repaired = true
	hive.refresh_visual()
	for inventory: InventoryComponent in world.tool_upgrades.wood_sources():
		inventory.changed.emit()
	world.player.wallet.changed.emit(world.player.wallet.balance)
	changed.emit()
	_lock(false)
	return ""

func collect(hive: Beehive) -> String:
	var error: String = access_error(hive)
	if not error.is_empty():
		return error
	world.workers.settle(world.farming.time_manager.now())
	error = access_error(hive)
	if not error.is_empty():
		return error
	_lock(true)
	var ok: bool = hive.collect(world.player.selection.inventory)
	changed.emit()
	_lock(false)
	return "" if ok else "Honey is not ready or your bag cannot hold the whole batch."

func _lock(value: bool) -> void:
	busy = value
	world.workers.busy = value
	world.storages.busy = value

func _crafted(id: String) -> void:
	var recipe: CookingRecipe = ChefCooking.find(id)
	if recipe != null and recipe.honey_recipe in HoneyComboCatalog.IDS and recipe.honey_recipe not in discoveries:
		discoveries.append(recipe.honey_recipe)
		changed.emit()
