extends RefCounted
## Scene-specific bridge. Backend and schema never retain live scene objects.
const Schema = preload("res://persistence/save_schema.gd")
const Catalog = preload("res://persistence/save_catalog.gd")
const Actor = preload("res://components/animals/animal_actor.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Trough = preload("res://components/animals/animal_trough.gd")
const Pickup = preload("res://components/item_pickup.gd")
const Farming = preload("res://components/farming_controller.gd")
const Selection = preload("res://components/tool_selection_component.gd")
const Garden = preload("res://components/flowers/flower_garden.gd")
const Pond = preload("res://components/animals/pond_pen.gd")
const ACTOR_SCENE: PackedScene = preload("res://scenes/animals/animal.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/objects/item_pickup.tscn")
var world: Node
var catalog: Catalog

func _init(scene: Node, resources: Catalog) -> void:
	world = scene
	catalog = resources

func _nodes(node: Node, script: Script) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if is_instance_of(child, script):
			result.append(child)
		result.append_array(_nodes(child, script))
	return result

func _id(node: Node) -> String:
	if String(node.persistent_id).is_empty():
		node.persistent_id = StringName("entity_" + Crypto.new().generate_random_bytes(16).hex_encode())
	return String(node.persistent_id)

func _pair(point: Vector2) -> Array:
	return [point.x, point.y]

func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))

func _cell(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))

func capture(profile: String, revision: int, now: float) -> Dictionary:
	var player: Node2D = world.get_node("Player") as Node2D
	var selection: Selection = player.get_node("ToolSelection") as Selection
	var farm: Farming = world.get_node("FarmingController") as Farming
	var animals: Array[Node] = _nodes(world, Actor)
	# Sync needs first: catch-up can create a product pile that belongs in this save.
	for animal: Actor in animals:
		animal.needs.update_at(now)
	var data: Dictionary = {"version": Schema.VERSION, "world_id": "main_world", "profile_id": profile, "revision": revision, "saved_at": now,
		"player": {"position": _pair(player.position), "facing": String(player.get_node("AnimationComponent").facing_direction), "selected_slot": selection.selected_index},
		"inventory": [], "soil": farm.capture_soil(), "crops": [], "animals": [], "troughs": [], "pickups": [], "flower_gardens": [], "animal_pens": []}
	for pen: Pen in _nodes(world, Pen):
		data.animal_pens.append(_id(pen))
	for garden: Garden in _nodes(world, Garden):
		data.flower_gardens.append(garden.capture(now))
	for index: int in range(selection.inventory.slot_count):
		var stack: Dictionary = selection.inventory.slot(index)
		data.inventory.append({"item": String(stack.item.item_id) if stack.item != null else "", "count": int(stack.count)})
	for cell: Vector2i in farm.crop_cells():
		var crop: Node = farm.get_crop(cell)
		crop.refresh(now)
		data.crops.append({"cell": [cell.x, cell.y], "crop": String(crop.definition.crop_id), "planted_at": crop.planted_at, "matures_at": crop.matures_at, "progress": crop.progress})
	for animal: Actor in animals:
		var pile: Pickup = animal.product_pickup()
		data.animals.append({"id": _id(animal), "pen": _id(animal.pen), "position": _pair(animal.pen.to_local(animal.global_position)), "animal": String(animal.definition.animal_id),
			"skin": catalog.skin_id(animal.skin_frames), "facing": String(animal.animation.facing_direction), "age": animal.growth.age_seconds,
			"satiety": animal.needs.satiety, "hydration": animal.needs.hydration, "production_progress": animal.production.progress_seconds, "production_stock": animal.production.stored_amount,
			"pickup": _id(pile) if pile != null else ""})
	for trough: Trough in _nodes(world, Trough):
		data.troughs.append({"id": _id(trough), "pen": _id(trough.pen), "position": _pair(trough.pen.to_local(trough.global_position)), "stock": trough.stock})
	for pile: Pickup in _nodes(world, Pickup):
		var pen: Pen = pile.get_parent() as Pen
		data.pickups.append({"id": _id(pile), "pen": _id(pen) if pen != null else "", "position": _pair(pen.to_local(pile.global_position) if pen != null else (world as Node2D).to_local(pile.global_position)), "item": String(pile.item.item_id), "amount": pile.amount})
	return data

func _index(script: Script) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _nodes(world, script):
		var id: String = _id(node)
		if result.has(id):
			return {}
		result[id] = node
	return result

func _saved_pens(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if data.has("animal_pens"):
		for id: String in data.animal_pens:
			result[id] = true
	else:
		for row: Dictionary in data.animals + data.troughs:
			result[row.pen] = true
	return result

func preflight(data: Dictionary) -> Dictionary:
	var checked: Dictionary = Schema.validate(data, catalog)
	if not checked.ok:
		return checked
	data = checked.snapshot
	var gardens: Dictionary = _index(Garden)
	for garden: Dictionary in data.flower_gardens:
		if not gardens.has(garden.id):
			return Schema.failure("Không tìm thấy vườn hoa của file lưu.")
	var pens: Dictionary = _index(Pen)
	var troughs: Dictionary = _index(Trough)
	var player: Node = world.get_node_or_null("Player")
	var farm: Farming = world.get_node_or_null("FarmingController") as Farming
	if pens.is_empty() or player == null or farm == null or farm.farmland == null or farm.farmland.tile_set == null or not farm.can_restore_soil():
		return Schema.failure("Cấu trúc thế giới chưa hỗ trợ tải.")
	var selection: Selection = player.get_node("ToolSelection") as Selection
	if data.inventory.size() != selection.inventory.slot_count or data.troughs.size() > troughs.size():
		return Schema.failure("Túi đồ hoặc danh sách máng đã thay đổi; cần migrate file lưu.")
	var initialized: Dictionary = _saved_pens(data)
	for id: String in initialized:
		if not pens.has(id):
			return Schema.failure("Không tìm thấy chuồng trong file lưu.")
	var saved_troughs: Dictionary = {}
	for row: Dictionary in data.troughs:
		saved_troughs[row.id] = true
		if not troughs.has(row.id) or not pens.has(row.pen) or troughs[row.id].pen != pens[row.pen] or row.stock > troughs[row.id].capacity:
			return Schema.failure("Không tìm thấy máng hoặc sức chứa đã thay đổi.")
	for id: String in troughs:
		if initialized.has(_id(troughs[id].pen)) and not saved_troughs.has(id):
			return Schema.failure("Thiếu máng của chuồng đã lưu.")
	for row: Dictionary in data.animals:
		if not pens.has(row.pen):
			return Schema.failure("Không tìm thấy chuồng của vật nuôi.")
	for row: Dictionary in data.pickups:
		if row.pen != "" and not pens.has(row.pen):
			return Schema.failure("Không tìm thấy chuồng của vật phẩm.")
	return {"ok": true, "snapshot": data}

func restore(data: Dictionary, now: float) -> Dictionary:
	var checked: Dictionary = preflight(data)
	if not checked.ok:
		return checked
	data = checked.snapshot
	var gardens: Dictionary = _index(Garden)
	var saved_gardens: Dictionary = {}
	for garden: Dictionary in data.flower_gardens:
		saved_gardens[garden.id] = true
	var pens: Dictionary = _index(Pen)
	var troughs: Dictionary = _index(Trough)
	var initialized: Dictionary = _saved_pens(data)
	var player: Node2D = world.get_node("Player") as Node2D
	var selection: Selection = player.get_node("ToolSelection") as Selection
	var farm: Farming = world.get_node("FarmingController") as Farming
	player.get_node("StateComponent").reset_after_load()
	selection.set_inventory_open(false)
	# Remove default entities before inventory.changed retries nearby pickups.
	for actor: Actor in _nodes(world, Actor):
		if not initialized.has(_id(actor.pen)):
			actor.needs.restore_state(actor.needs.satiety, actor.needs.hydration, maxf(now, data.saved_at))
			continue
		actor.foraging.cancel()
		actor.free()
	for pile: Pickup in _nodes(world, Pickup):
		if pile.get_parent() is Pen and not initialized.has(_id(pile.get_parent())):
			continue
		pile.free()
	for garden: Garden in gardens.values():
		garden.reset()
		# Initialize a new map feature when loading an older profile; on later
		# saves its garden ID and remaining pickups are captured normally.
		if not saved_gardens.has(String(garden.persistent_id)):
			garden.restore_initial_supplies()
			garden.add_starter_flowers(maxf(now, data.saved_at))
	for row: Dictionary in data.flower_gardens:
		var garden: Garden = gardens[row.id]
		for flower: Dictionary in row.flowers:
			garden.pots[_cell(flower.cell)].restore_state(flower, catalog.flowers[flower.flower], maxf(now, data.saved_at))
		garden.starter_flowers_added = bool(row.get("starter_flowers_added", false))
		garden.add_starter_flowers(maxf(now, data.saved_at))
	farm.restore_soil(data.soil)
	for row: Dictionary in data.crops:
		farm.restore_crop(_cell(row.cell), catalog.crops[row.crop], row.planted_at, row.matures_at, row.progress, now)
	for row: Dictionary in data.troughs:
		var trough: Trough = troughs[row.id]
		trough.global_position = (pens[row.pen] as Pen).to_global(_point(row.position))
		trough.stock = int(row.stock)
	for pen: Pen in pens.values():
		if pen is Pond:
			(pen as Pond).rebuild_after_load()
	player.position = _point(data.player.position)
	player.get_node("AnimationComponent").facing_direction = StringName(data.player.facing)
	player.get_node("AnimationComponent").play("idle", true)
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	var slots: Array[Dictionary] = []
	for stack: Dictionary in data.inventory:
		slots.append({"item": catalog.items.get(stack.item), "count": int(stack.count)})
	selection.inventory.replace_slots(slots)
	selection.select_slot(int(data.player.selected_slot))
	var piles: Dictionary = {}
	for row: Dictionary in data.pickups:
		var pile: Pickup = PICKUP_SCENE.instantiate() as Pickup
		pile.persistent_id = StringName(row.id)
		pile.item = catalog.items[row.item]
		pile.amount = int(row.amount)
		var parent: Node2D = pens[row.pen] if row.pen != "" else world
		parent.add_child(pile)
		pile.position = _point(row.position)
		if parent is Pond and (parent as Pond).is_water(pile.global_position):
			pile.global_position = (parent as Pond).closest_land(pile.global_position)
		piles[row.id] = pile
	for row: Dictionary in data.animals:
		var actor: Actor = ACTOR_SCENE.instantiate() as Actor
		actor.persistent_id = StringName(row.id)
		actor.definition = catalog.animals[row.animal]
		actor.skin_frames = catalog.load_skin(row.skin)
		actor.pen = pens[row.pen]
		actor.get_node("NeedsComponent").time_manager = farm.time_manager
		actor.pen.add_child(actor)
		actor.global_position = actor.pen.clamp_world(actor.pen.to_global(_point(row.position)), actor.wander.margin)
		actor.animation.facing_direction = StringName(row.facing)
		actor.restore_lifecycle(row, data.saved_at, maxf(now, data.saved_at), piles.get(row.pickup) as Pickup)
	return {"ok": true}
