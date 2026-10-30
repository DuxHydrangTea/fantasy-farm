class_name WorldStateAdapter
extends RefCounted
## Scene-specific bridge. Backend and schema never retain live scene objects.
const ACTOR_SCENE: PackedScene = preload("res://scenes/animals/animal.tscn")
var world: FarmWorld
var catalog: SaveCatalog

func _init(scene: FarmWorld, resources: SaveCatalog) -> void:
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

func _collect_world_entities() -> Dictionary:
	var entities: Dictionary = {
		"animals": [] as Array[Node],
		"pens": [] as Array[Node],
		"gardens": [] as Array[Node],
		"troughs": [] as Array[Node],
		"pickups": [] as Array[Node]
	}
	_walk_entities(world, entities)
	return entities

func _walk_entities(node: Node, entities: Dictionary) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is AnimalActor:
			entities.animals.append(child)
		elif child is AnimalPen:
			entities.pens.append(child)
		elif child is FlowerGarden:
			entities.gardens.append(child)
		elif child is AnimalTrough:
			entities.troughs.append(child)
		elif child is ItemPickup:
			entities.pickups.append(child)
		_walk_entities(child, entities)

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
	world.workers.settle(now)
	world.starter_content.refresh()
	var player: FarmPlayer = world.player
	var selection: ToolSelectionComponent = player.selection
	var farm: FarmingController = world.farming
	if world.weather != null:
		world.weather.advance(now)
	if world.apiary != null:
		world.apiary.advance(now)
	var entities: Dictionary = _collect_world_entities()
	var animals: Array[Node] = entities.animals
	# Sync needs first: catch-up can create a product pile that belongs in this save.
	for animal: AnimalActor in animals:
		animal.needs.update_at(now)
	# Catch-up may retire actors and create product piles. Collect the committed result.
	entities = _collect_world_entities()
	animals = entities.animals
	var data: Dictionary = {"version": SaveSchema.VERSION, "world_id": "main_world", "profile_id": profile, "revision": revision, "saved_at": now,
		"player": {"position": _pair(player.position), "facing": String(player.animation.facing_direction), "selected_slot": selection.selected_index},
		"land_columns": farm.land.unlocked_columns if farm.land != null else LandExpansionState.REGION.size.x, "coins": player.wallet.balance, "inventory": [], "soil": farm.capture_soil(), "crops": [], "animals": [], "troughs": [], "pickups": [], "flower_gardens": [], "animal_pens": [], "beehives": []}
	# Dùng String tường minh: gán key mới bằng dấu chấm tạo StringName trên Godot 4.7,
	# khiến bộ ghi async từ chối DTO dù dữ liệu có thể stringify thành JSON.
	data["weather"] = world.weather.schedule.capture() if world.weather != null else WeatherSchedule.new().capture()
	data["trees"] = world.trees.capture(now) if world.trees != null else []
	data["objectives"] = world.objectives.progress.capture() if world.objectives != null and world.objectives.progress != null else ObjectiveSaveSchema.fresh(ObjectiveProgress.DEFAULT_CATALOG)
	data["orders"] = world.orders.service.capture() if world.orders != null and world.orders.service != null else OrderSaveSchema.fresh()
	data["tutorial"] = world.tutorial.capture()
	data["tool_upgrades"] = world.tool_upgrade_state.capture()
	data["pen_upgrades"] = world.pen_upgrades.state.capture()
	data["tree_plot_upgrades"] = world.tree_plot_upgrades.state.capture()
	data["cooking"] = world.cooking.capture(now)
	data["fertile_layout_version"] = farm.fertility.layout_version
	data["honey_garden"] = world.honey_garden.capture()
	data["wood_market"] = world.wood_market.capture(now)
	data["workers"] = world.workers.capture(now)
	data["storages"] = world.storages.capture()
	data["storage_seed"] = String(selection.storage_seed_id)
	data["land_starting_columns"] = farm.land.starting_columns
	data["flower_garden_unlocked"] = world.starter_content.flower_garden_unlocked
	data["pen_updated_at"] = {}
	if world.apiary != null:
		for hive: Beehive in world.apiary.hives:
			data.beehives.append(hive.capture())
	for pen: AnimalPen in entities.pens:
		data.animal_pens.append(_id(pen))
		data.pen_updated_at[_id(pen)] = now
	for garden: FlowerGarden in entities.gardens:
		data.flower_gardens.append(garden.capture(now))
	for index: int in range(selection.inventory.slot_count):
		var stack: Dictionary = selection.inventory.slot(index)
		data.inventory.append({"item": String(stack.item.item_id) if stack.item != null else "", "count": int(stack.count), "tiers": stack.tiers.duplicate()})
	for cell: Vector2i in farm.crop_cells():
		var crop: Crop = farm.get_crop(cell)
		crop.refresh(now)
		data.crops.append({"cell": [cell.x, cell.y], "crop": String(crop.definition.crop_id), "planted_at": crop.planted_at, "matures_at": crop.matures_at, "progress": crop.progress, "watered": crop.watered, "root_boost": crop.root_boost, "fertilized": crop.fertilized,"pollination_reduction":crop.pollination_reduction, "conditions": crop.conditions.capture()})
	for animal: AnimalActor in animals:
		if animal.is_dead() or animal.is_queued_for_deletion():
			continue # Sync above may have reached the lifetime limit in this very capture.
		var pile: ItemPickup = animal.product_pickup()
		data.animals.append({"id": _id(animal), "pen": _id(animal.pen), "position": _pair(animal.pen.to_local(animal.global_position)), "animal": String(animal.definition.animal_id),
			"skin": catalog.skin_id(animal.skin_frames), "facing": String(animal.animation.facing_direction), "age": animal.growth.age_seconds,
			"satiety": animal.needs.satiety, "hydration": animal.needs.hydration, "production_progress": animal.production.progress_seconds, "production_stock": animal.production.stored_amount,
			"pickup": _id(pile) if pile != null else "", "juvenile_tonic_used": animal.growth.juvenile_tonic_used, "tonic_pending": animal.production.tonic_pending, "health": animal.health.capture()})
	for trough: AnimalTrough in entities.troughs:
		data.troughs.append({"id": _id(trough), "pen": _id(trough.pen), "position": _pair(trough.pen.to_local(trough.global_position)), "stock": trough.stock, "feed_reserve": trough.feed_reserve, "consumed_fraction": trough.consumed_fraction})
	for pile: ItemPickup in entities.pickups:
		var pen: AnimalPen = pile.get_parent() as AnimalPen
		data.pickups.append({"id": _id(pile), "pen": _id(pen) if pen != null else "", "position": _pair(pen.to_local(pile.global_position) if pen != null else (world as Node2D).to_local(pile.global_position)), "item": String(pile.item.item_id), "amount": pile.amount})
	return data

func _index_nodes(nodes: Array[Node]) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in nodes:
		var id: String = _id(node)
		if result.has(id):
			return {}
		result[id] = node
	return result

func _index(script: Script) -> Dictionary:
	return _index_nodes(_nodes(world, script))

func _saved_pens(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if data.has("animal_pens"):
		for id: String in data.animal_pens:
			result[id] = true
	else:
		for row: Dictionary in data.animals + data.troughs:
			result[row.pen] = true
	return result

# Kiểm tra liên kết save với map hiện tại trước khi thay inventory, xóa actor hoặc dựng lại cây.
# Không chỉ kiểm tra kiểu JSON: còn phải có đúng pen/garden/trough, sức chứa và số ô inventory.
# Nếu vừa xóa thế giới cũ vừa phát hiện lỗi ở giữa restore, có thể để game trong trạng thái nửa cũ nửa mới.
# Khi cấu trúc map thay đổi có chủ ý, cần migration rõ ràng thay vì bỏ qua các check để "tải cho được".
func preflight(data: Dictionary) -> Dictionary:
	var checked: Dictionary = SaveSchema.validate(data, catalog)
	if not checked.ok:
		return checked
	data = checked.snapshot.duplicate(true)
	if world.tree_plot_upgrades != null and world.tree_plot_upgrades.state.is_busy():
		return SaveSchema.failure("A tree plot upgrade is in progress.", "busy")
	if world.pen_upgrades != null and world.pen_upgrades.state.is_busy():
		return SaveSchema.failure("A pen upgrade is in progress.", "busy")
	if world.trees != null and world.trees.is_busy():
		return SaveSchema.failure("A forestry action is in progress.", "busy")
	if world.farming != null and world.farming.is_area_busy():
		return SaveSchema.failure("A farming action is in progress.", "busy")
	if world.storages == null or world.storages.busy:
		return SaveSchema.failure("A storage transaction is in progress.", "busy")
	if world.workers == null or world.workers.busy:
		return SaveSchema.failure("A worker transaction is in progress.", "busy")
	for row: Dictionary in data.workers.rows:
		if row.role == "ranch" and world.workers.bridge.pen_for(row.zone) == null:
			return SaveSchema.failure("The worker pen was not found.")
		var worker_position: Vector2 = WorkerRole.point(row.position)
		var camera: Camera2D = world.player.camera
		var world_bounds: Rect2 = Rect2(Vector2(camera.limit_left, camera.limit_top), Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top))
		# Strolling workers legitimately stand and target anywhere in the world;
		# only work targets must stay inside the worker's own zone.
		if not world_bounds.has_point(worker_position):
			return SaveSchema.failure("Invalid worker position.")
		if not row.task.is_empty() and String(row.task.get("kind", "")) != "patrol" and not world.workers.bridge.zone_contains(row, WorkerRole.point(row.task.point), int(data.land_columns)):
			return SaveSchema.failure("Invalid worker target.")
	if world.wood_market == null or world.wood_market.busy:
		return SaveSchema.failure("A wood purchase is in progress.", "busy")
	if world.cooking == null or world.cooking.busy:
		return SaveSchema.failure("A cooking transaction is in progress.", "busy")
	if world.tool_upgrade_state == null or world.tool_upgrade_state.is_busy():
		return SaveSchema.failure("A tool upgrade transaction is in progress.", "busy")
	if world.apiary == null or world.weather == null or world.objectives == null or world.objectives.progress == null or world.orders == null or world.orders.service == null:
		return SaveSchema.failure("Restart the game before loading this save.")
	var entities: Dictionary = _collect_world_entities()
	var gardens: Dictionary = _index_nodes(entities.gardens)
	for garden: Dictionary in data.flower_gardens:
		if not gardens.has(garden.id):
			return SaveSchema.failure("The saved flower garden was not found.")
	var pens: Dictionary = _index_nodes(entities.pens)
	var troughs: Dictionary = _index_nodes(entities.troughs)
	for id: String in data.pen_updated_at:
		if not pens.has(id):
			return SaveSchema.failure("The saved simulation pen was not found.")
	var player: FarmPlayer = world.player
	var farm: FarmingController = world.farming
	if pens.is_empty() or player == null or farm == null or farm.farmland == null or farm.farmland.tile_set == null or not farm.can_restore_soil():
		return SaveSchema.failure("This world layout does not support loading.")
	var selection: ToolSelectionComponent = player.selection
	if data.inventory.size() != selection.inventory.slot_count or data.troughs.size() > troughs.size():
		return SaveSchema.failure("Inventory or trough layout changed; the save needs migration.")
	var initialized: Dictionary = _saved_pens(data)
	for id: String in initialized:
		if not pens.has(id):
			return SaveSchema.failure("The saved pen was not found.")
	var saved_troughs: Dictionary = {}
	for row: Dictionary in data.troughs:
		saved_troughs[row.id] = true
		if not troughs.has(row.id) or not pens.has(row.pen) or troughs[row.id].pen != pens[row.pen] or row.stock > troughs[row.id].capacity:
			return SaveSchema.failure("A trough was not found or its capacity changed.")
		var trough: AnimalTrough = troughs[row.id]
		if (trough.kind == AnimalTrough.Kind.WATER and row.feed_reserve != 0) or (trough.kind == AnimalTrough.Kind.FOOD and (trough.feed_item == null or row.feed_reserve >= trough.feed_item.food_units_per_item)):
			return SaveSchema.failure("Invalid retained trough feed.")
	for id: String in troughs:
		if initialized.has(_id(troughs[id].pen)) and not saved_troughs.has(id):
			return SaveSchema.failure("A saved pen is missing a trough.")
	for row: Dictionary in data.animals:
		if not pens.has(row.pen):
			return SaveSchema.failure("The animal's pen was not found.")
	for row: Dictionary in data.pickups:
		if row.pen != "" and not pens.has(row.pen):
			return SaveSchema.failure("The item's pen was not found.")
	if world.honey_garden == null or world.honey_garden.busy:
		return SaveSchema.failure("A garden transaction is in progress.","busy")
	var garden_slots: Dictionary = {}
	var hive_cells: Dictionary = {}
	for row: Dictionary in data.beehives:
		var point: Vector2 = world.to_global(_point(row.position))
		# Garden hives use the path anchors; older saves may still put them inside beds.
		if int(row.garden_slot) >= 0 and world.honey_garden.garden() != null and row.garden_id == String(world.honey_garden.garden().persistent_id):
			point = world.honey_garden.center_point(int(row.garden_slot))
			var local_point: Vector2 = world.to_local(point)
			row.position = [local_point.x, local_point.y]
		var cell: Vector2i = farm.world_to_cell(point)
		var placement_ok: bool = true
		if int(row.garden_slot) >= 0:
			var slot: int = int(row.garden_slot)
			placement_ok = world.honey_garden.garden() != null and row.garden_id == String(world.honey_garden.garden().persistent_id) and not garden_slots.has(slot) and world.apiary.placement_error(point, int(data.land_columns), true, true).is_empty()
			garden_slots[slot] = true
		else:
			placement_ok = world.apiary.placement_error(point,int(data.land_columns),true,not data.honey_garden.migrated).is_empty()
			if data.honey_garden.migrated and world.honey_garden.garden() != null and Rect2(Vector2.ZERO,FlowerGarden.SIZE).has_point(world.honey_garden.garden().to_local(point)):
				placement_ok = false
		if (int(row.garden_slot) < 0 and point.distance_to(world.apiary.snap_position(point)) > 0.01) or hive_cells.has(cell) or not placement_ok:
			return SaveSchema.failure("Invalid beehive placement.")
		for crop: Dictionary in data.crops:
			if _cell(crop.cell) == cell:
				return SaveSchema.failure("A hive overlaps a saved crop.")
		hive_cells[cell] = true
	if data.honey_garden.migrated and garden_slots.size() != 3:
		return SaveSchema.failure("The garden needs exactly three fixed hives.")
	for row: Dictionary in data.trees:
		var cell: Vector2i = _cell(row.cell)
		if world.trees == null or hive_cells.has(cell):
			return SaveSchema.failure("Invalid tree placement.")
		var ground: TileMapLayer = world.farming.ground
		var point: Vector2 = world.trees.point_for(cell)
		if ground.get_cell_source_id(ground.local_to_map(ground.to_local(point))) < 0:
			return SaveSchema.failure("Tree ground was not found.")
	return {"ok": true, "snapshot": data}

func restore(data: Dictionary, now: float) -> Dictionary:
	var result: Dictionary = _restore_checkpoint(data, now)
	if not result.ok:
		return result
	world.workers.advance(maxf(now, data.saved_at))
	return _finish_restore(maxf(now, data.saved_at), float(result.previous_simulation))

func restore_async(data: Dictionary, now: float) -> Dictionary:
	var result: Dictionary = _restore_checkpoint(data, now)
	if not result.ok:
		return result
	await world.workers.advance_async(maxf(now, data.saved_at))
	return _finish_restore(maxf(now, data.saved_at), float(result.previous_simulation))

func restore_without_offline(data: Dictionary) -> Dictionary:
	var result: Dictionary = _restore_checkpoint(data, float(data.saved_at))
	if not result.ok:
		return result
	return _finish_restore(float(data.saved_at), float(result.previous_simulation))

func _restore_checkpoint(data: Dictionary, now: float) -> Dictionary:
	var checked: Dictionary = preflight(data)
	if not checked.ok:
		return checked
	data = checked.snapshot
	var clock: FarmClock = world.farming.time_manager
	var previous_simulation: float = clock.simulation_timestamp
	clock.simulation_timestamp = float(data.saved_at)
	world.objectives.progress.suspended = true
	world.starter_content.begin_restore(data.flower_garden_unlocked)
	var entities: Dictionary = _collect_world_entities()
	var gardens: Dictionary = _index_nodes(entities.gardens)
	var saved_gardens: Dictionary = {}
	for garden: Dictionary in data.flower_gardens:
		saved_gardens[garden.id] = true
	var pens: Dictionary = _index_nodes(entities.pens)
	var troughs: Dictionary = _index_nodes(entities.troughs)
	var initialized: Dictionary = _saved_pens(data)
	var player: FarmPlayer = world.player
	var selection: ToolSelectionComponent = player.selection
	var farm: FarmingController = world.farming
	# Dọn menu/hiệu ứng và trạng thái hành động trước khi restore để Tween/hành động cũ không
	# tiếp tục commit vào thế giới vừa tải. Xóa entity mặc định trước inventory.changed của restore,
	# vì signal đó có thể làm sensor thử nhặt các đống cũ; làm ngược thứ tự có thể cấp đồ lại từ mặc định.
	world.apiary.begin_restore()
	world.honey_garden.restore(data.honey_garden)
	if world.trees != null:
		world.trees.reset()
	world.weather.restore(data.weather, float(data.saved_at))
	player.shop_interaction.close_for_load()
	world.storages.restore(data.storages, catalog)
	player.selection.set_objectives_open(false)
	if world.land != null:
		world.land.reset_presentation()
	if farm.land != null:
		farm.land.restore_columns(int(data.land_columns), int(data.land_starting_columns))
	world.wood_market.restore(data.wood_market)
	world.tool_upgrade_state.restore(data.tool_upgrades, false)
	world.pen_upgrades.restore(data.pen_upgrades)
	world.tree_plot_upgrades.restore(data.tree_plot_upgrades)
	world.cooking.restore(data.cooking, maxf(now, data.saved_at))
	player.item_feedback.clear()
	player.wallet.set_balance(int(data.coins))
	player.state.reset_after_load()
	if player.mobile_controls != null:
		player.mobile_controls.reset_input()
	selection.set_inventory_open(false)
	# Remove default entities before inventory.changed retries nearby pickups.
	for actor: AnimalActor in entities.animals:
		if not initialized.has(_id(actor.pen)):
			actor.needs.restore_state(actor.needs.satiety, actor.needs.hydration, maxf(now, data.saved_at))
			continue
		actor.foraging.cancel()
		actor.free()
	for pile: ItemPickup in entities.pickups:
		if pile.get_parent() is AnimalPen and not initialized.has(_id(pile.get_parent())):
			continue
		pile.free()
	for garden: FlowerGarden in gardens.values():
		garden.reset()
		# Initialize a new map feature when loading an older profile; on later
		# saves its garden ID and remaining pickups are captured normally.
		if not saved_gardens.has(String(garden.persistent_id)):
			garden.restore_initial_supplies()
			garden.add_starter_flowers(maxf(now, data.saved_at))
	for row: Dictionary in data.flower_gardens:
		var garden: FlowerGarden = gardens[row.id]
		for flower: Dictionary in row.flowers:
			garden.restore_flower(flower, catalog.flowers[flower.flower], float(data.saved_at))
		garden.starter_flowers_added = bool(row.get("starter_flowers_added", false))
		garden.add_starter_flowers(maxf(now, data.saved_at))
	farm.fertility.layout_version = int(data.fertile_layout_version)
	(world.get_node("FertileSoil") as FertileSoilOverlay).queue_redraw()
	farm.restore_soil(data.soil)
	world.weather.advance(float(data.saved_at))
	for row: Dictionary in data.crops:
		farm.restore_crop(_cell(row.cell), catalog.crops[row.crop], row.planted_at, row.matures_at, row.progress, float(data.saved_at), bool(row.fertilized), float(row.pollination_reduction), bool(row.watered), bool(row.root_boost), row.conditions)
	world.apiary.restore(data.beehives,float(data.saved_at),float(data.saved_at))
	if world.trees != null:
		world.trees.restore(data.trees, float(data.saved_at))
	farm._refresh_crops(float(data.saved_at))
	for garden: FlowerGarden in gardens.values():
		garden.restore_legacy_flowers()
		garden.refresh(float(data.saved_at)) # Replay bees/crops with workers on one timeline.
	for row: Dictionary in data.troughs:
		var trough: AnimalTrough = troughs[row.id]
		# Troughs are authored in the scene; old saved coordinates must not override layout edits.
		trough.feed_reserve = int(row.feed_reserve)
		trough.stock = int(row.stock)
		trough.consumed_fraction = float(row.consumed_fraction)
	for pen: AnimalPen in pens.values():
		if pen is PondPen:
			(pen as PondPen).rebuild_after_load()
	player.position = _point(data.player.position)
	player.animation.facing_direction = StringName(data.player.facing)
	player.animation.play("idle", true)
	var camera: Camera2D = player.camera
	if camera != null:
		camera.reset_smoothing()
	var slots: Array[Dictionary] = []
	for stack: Dictionary in data.inventory:
		slots.append({"item": catalog.items.get(stack.item), "count": int(stack.count), "tiers": stack.tiers.duplicate()})
	selection.inventory.replace_slots(slots)
	selection.select_slot(int(data.player.selected_slot))
	selection.select_storage_seed(StringName(data.storage_seed))
	var piles: Dictionary = {}
	for row: Dictionary in data.pickups:
		var pile: ItemPickup = ItemPickup.create()
		pile.persistent_id = StringName(row.id)
		pile.item = catalog.items[row.item]
		pile.amount = int(row.amount)
		var parent: Node2D = pens[row.pen] if row.pen != "" else world
		parent.add_child(pile)
		pile.position = _point(row.position)
		if parent is PondPen and (parent as PondPen).is_water(pile.global_position):
			pile.global_position = (parent as PondPen).closest_land(pile.global_position)
		piles[row.id] = pile
	for row: Dictionary in data.animals:
		var actor: AnimalActor = ACTOR_SCENE.instantiate() as AnimalActor
		actor.persistent_id = StringName(row.id)
		actor.definition = catalog.animals[row.animal]
		actor.skin_frames = catalog.load_skin(row.skin)
		actor.pen = pens[row.pen]
		actor.needs.time_manager = farm.time_manager
		actor.pen.add_child(actor)
		actor.global_position = actor.pen.clamp_world(actor.pen.to_global(_point(row.position)), actor.wander.margin)
		actor.animation.facing_direction = StringName(row.facing)
		# Build the entire herd at the same checkpoint before sharing any trough stock.
		actor.restore_lifecycle(row, float(data.pen_updated_at[row.pen]), float(data.pen_updated_at[row.pen]), piles.get(row.pickup) as ItemPickup)
	for pen: AnimalPen in pens.values():
		pen.advance_offline(float(data.saved_at), true)
	if player.state.navigation != null:
		player.state.navigation.invalidate_cache()
	world.orders.service.restore(data.orders)
	world.tutorial.restore(data.tutorial)
	world.objectives.progress.restore(data.objectives)
	world.objectives.progress.suspended = false
	world.workers.restore(data.workers, catalog)
	return {"ok": true, "previous_simulation": previous_simulation}

func _finish_restore(now: float, previous_simulation: float) -> Dictionary:
	world.workers.bridge.sync(now)
	world.weather.advance(now) # Publish final lighting/HUD once after offline replay.
	for garden: FlowerGarden in world.apiary.gardens:
		garden.refresh(now)
	world.farming.time_manager.simulation_timestamp = previous_simulation
	world.starter_content.finish_restore()
	world.tool_upgrade_state.notify_restored()
	world.objectives.progress.restored.emit()
	world.objectives.progress.changed.emit()
	return {"ok": true}
