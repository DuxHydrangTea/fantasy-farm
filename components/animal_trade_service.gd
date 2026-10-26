class_name AnimalTradeService
extends RefCounted
## Live animal trades belong to the same farm as the customer, outside the bag.
signal purchased(offer: AnimalShopOffer, quantity: int, total: int)
signal sold(animal_id: StringName, total: int)
const ACTOR_PATH: String = "res://scenes/animals/animal.tscn"
var catalog: ShopCatalog
var wallet: WalletComponent
var farm: Node
var clock: FarmClock
var _busy: bool = false

func _init(stock: ShopCatalog, purse: WalletComponent, farm_root: Node, time_source: FarmClock) -> void:
	catalog = stock
	wallet = purse
	farm = farm_root
	clock = time_source

func _pens() -> Array[AnimalPen]:
	var result: Array[AnimalPen] = []
	if is_instance_valid(farm) and farm.is_inside_tree():
		for child: Node in farm.get_children():
			if child is AnimalPen and not child.is_queued_for_deletion():
				result.append(child as AnimalPen)
	return result

func owned_animals() -> Array[AnimalActor]:
	var result: Array[AnimalActor] = []
	for pen: AnimalPen in _pens():
		for child: Node in pen.get_children():
			var animal: AnimalActor = child as AnimalActor
			if _alive(animal) and animal.pen == pen:
				result.append(animal)
	return result

func _alive(animal: AnimalActor) -> bool:
	return is_instance_valid(animal) and animal.is_inside_tree() and not animal.is_queued_for_deletion() and not animal.is_dead() and not animal.growth.is_dead()

func _offer_for(animal: AnimalActor) -> AnimalShopOffer:
	if catalog != null and _alive(animal) and animal.definition != null:
		for offer: AnimalShopOffer in catalog.animal_offers:
			if offer != null and offer.is_valid() and offer.animal.animal_id == animal.definition.animal_id:
				return offer
	return null

func _owns(animal: AnimalActor) -> bool:
	return _alive(animal) and _pens().has(animal.pen) and animal.get_parent() == animal.pen

func quote_sell(animal: AnimalActor) -> Dictionary:
	var offer: AnimalShopOffer = _offer_for(animal)
	if offer == null or not _owns(animal):
		return {"ok": false, "error": "This animal is no longer on your farm or cannot be sold."}
	var total: int = offer.resale_price(animal.growth.is_adult())
	if not is_instance_valid(wallet) or total > WalletComponent.MAX_COINS - wallet.balance:
		return {"ok": false, "error": "Your wallet has reached its coin limit."}
	return {"ok": true, "total": total}

func sell(animal: AnimalActor) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "A trade is in progress."}
	if not _owns(animal) or not is_instance_valid(clock):
		return {"ok": false, "error": "This animal cannot be sold."}
	_busy = true
	# Synchronize BEFORE valuing the animal: a late click cannot sell after death.
	animal.needs.update_at(clock.now())
	var checked: Dictionary = quote_sell(animal)
	if not checked.ok:
		_busy = false
		return checked
	var id: StringName = animal.persistent_id
	var previous: int = wallet.balance
	wallet.set_balance(previous + int(checked.total), false)
	if not animal.retire_for_sale():
		wallet.set_balance(previous, false)
		_busy = false
		return {"ok": false, "error": "The animal has changed."}
	# Observers see both the credited wallet and the retired animal.
	wallet.changed.emit(wallet.balance)
	sold.emit(id, int(checked.total))
	_busy = false
	return checked

func quote_buy(offer: AnimalShopOffer, quantity: int) -> Dictionary:
	if catalog == null or offer == null or not catalog.animal_offers.has(offer) or not offer.is_valid() or quantity < 1 or quantity > 99:
		return {"ok": false, "error": "Invalid animal or quantity."}
	if not is_instance_valid(wallet) or not is_instance_valid(clock):
		return {"ok": false, "error": "Animal trading is unavailable."}
	var total: int = offer.price * quantity
	if wallet.balance < total:
		return {"ok": false, "error": "Not enough coins."}
	var full_managed_pen: bool = false
	var free_capacity: bool = false
	for pen: AnimalPen in _pens():
		if not pen.accepted_species.has(offer.animal.species):
			continue
		var population: int = 0
		for child: Node in pen.get_children():
			if _alive(child as AnimalActor):
				population += 1
		if population + quantity <= pen.capacity:
			free_capacity = true
		elif farm is FarmWorld and (farm as FarmWorld).pen_upgrades != null and (farm as FarmWorld).pen_upgrades.managed(pen) and pen.capacity < 30:
			full_managed_pen = true
		var positions: Array[Vector2] = _spawn_positions(pen, offer.animal, quantity)
		if positions.size() == quantity:
			return {"ok": true, "total": total, "pen": pen, "positions": positions}
	if full_managed_pen and not free_capacity:
		return {"ok":false, "error":"This pen is full. Open its management board to unlock more spaces."}
	return {"ok": false, "error": "A suitable pen is full or has no free space."}

func buy(offer: AnimalShopOffer, quantity: int) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "A trade is in progress."}
	if is_instance_valid(clock):
		for pen: AnimalPen in _pens():
			pen.sync_before_change(clock.now())
	var checked: Dictionary = quote_buy(offer, quantity)
	if not checked.ok:
		return checked
	# Load after global scripts have initialized. The world/shop/animal script
	# graph can otherwise retain an empty PackedScene during a cyclic preload.
	var actor_scene: PackedScene = load(ACTOR_PATH) as PackedScene
	if actor_scene == null or not actor_scene.can_instantiate():
		return {"ok": false, "error": "Animal trading is unavailable."}
	_busy = true
	var pen: AnimalPen = checked.pen
	var actors: Array[AnimalActor] = []
	for point: Vector2 in checked.positions:
		var animal: AnimalActor = actor_scene.instantiate() as AnimalActor
		animal.definition = offer.animal
		animal.pen = pen
		animal.initial_age_seconds = 0.0
		animal.position = point
		animal.persistent_id = StringName("animal_" + Crypto.new().generate_random_bytes(16).hex_encode())
		animal.needs.time_manager = clock
		actors.append(animal)
	wallet.set_balance(wallet.balance - int(checked.total), false)
	for animal: AnimalActor in actors:
		pen.add_child(animal)
	wallet.changed.emit(wallet.balance)
	purchased.emit(offer, quantity, int(checked.total))
	_busy = false
	return {"ok": true, "quantity": quantity, "total": checked.total, "animals": actors}

func _spawn_positions(pen: AnimalPen, data: AnimalDefinition, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var occupied: Array[Rect2] = []
	var population: int = 0
	for child: Node in pen.get_children():
		var actor: AnimalActor = child as AnimalActor
		if _alive(actor):
			population += 1
			occupied.append(Rect2(pen.to_local(actor.global_position) - actor.definition.footprint * 0.5, actor.definition.footprint).grow(4.0))
	if population + count > pen.capacity:
		return positions
	var margin: float = maxf(data.pen_margin, data.footprint.length() * 0.5)
	var area: Rect2 = pen.allowed_bounds(margin)
	var step: Vector2 = (data.footprint + Vector2(8, 8)).max(Vector2(16, 16))
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = data.footprint
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 5 # World obstacles and existing animals.
	for y: int in range(floori(area.size.y / step.y) + 1):
		for x: int in range(floori(area.size.x / step.x) + 1):
			var point: Vector2 = area.position + Vector2(x, y) * step
			var rect: Rect2 = Rect2(point - data.footprint * 0.5, data.footprint)
			var blocked: bool = false
			for other: Rect2 in occupied:
				if rect.intersects(other):
					blocked = true
					break
			if blocked:
				continue
			var world_point: Vector2 = pen.to_global(point)
			if pen is PondPen:
				var pond: PondPen = pen as PondPen
				if not pond.navigation_ready or pond.is_water(world_point) or pond.route(world_point, world_point, data.can_swim).is_empty():
					continue # All newly bought birds arrive on safe, navigable shore.
			query.transform = pen.global_transform
			query.transform.origin = pen.to_global(point + Vector2(0, -3))
			if not pen.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			positions.append(point)
			occupied.append(rect.grow(4.0))
			if positions.size() == count:
				return positions
	return positions
