class_name BoosterService
extends RefCounted
## Commands synchronize old time, validate, then consume exactly one item on success.
var _busy: bool = false

func use(farm: FarmingController, cell: Vector2i, animal: AnimalActor, bag: InventoryComponent, slot: int, item: ItemDefinition, actor: PhysicsBody2D) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "A booster is being applied."}
	if bag == null or item == null or item.item_type != ItemDefinition.ItemType.BOOSTER or bag.slot(slot).item != item or bag.slot(slot).count < 1:
		return {"ok": false, "error": "The selected item changed."}
	_busy = true
	var error: String = ""
	var applied: bool = false
	if item.booster_kind == ItemDefinition.BoosterKind.FERTILIZER:
		error = farm.fertilizer_error(cell, actor) if is_instance_valid(farm) else "No crop to fertilize."
		if error.is_empty():
			applied = farm.fertilize(cell, actor)
	elif item.booster_kind == ItemDefinition.BoosterKind.ROOT_TONIC:
		error = farm.root_error(cell, actor) if is_instance_valid(farm) else "No crop to fertilize."
		if error.is_empty():
			applied = farm.apply_root(cell, actor)
	elif item.booster_kind == ItemDefinition.BoosterKind.PESTICIDE:
		error = farm.care_error(cell, true, actor) if is_instance_valid(farm) else "This plot is unavailable."
		if error.is_empty():
			applied = farm.treat_crop(cell, true, actor)
	else:
		if is_instance_valid(animal) and not animal.is_queued_for_deletion():
			# Never give an offline interval the benefit of a tonic applied afterward.
			if animal.needs.time_manager != null:
				animal.needs.update_at(animal.needs.time_manager.now())
			if item.booster_kind == ItemDefinition.BoosterKind.ANIMAL_MEDICINE and (actor == null or actor.get_world_2d() != animal.get_world_2d() or actor.global_position.distance_to(animal.global_position) > 32.0):
				error = "Move closer to the animal."
			elif item.booster_kind == ItemDefinition.BoosterKind.ANIMAL_MEDICINE and not actor.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(actor.global_position, animal.global_position, 1, [actor.get_rid(), animal.get_rid()])).is_empty():
				error = "Move closer to the animal."
			elif item.booster_kind == ItemDefinition.BoosterKind.ANIMAL_MEDICINE:
				applied = animal.cure_disease()
				error = "This animal is not sick." if not applied else ""
			else:
				error = animal.tonic_error()
				if error.is_empty():
					applied = animal.apply_tonic()
		else:
			error = "Face a nearby sick animal to use medicine." if item.booster_kind == ItemDefinition.BoosterKind.ANIMAL_MEDICINE else "Face a nearby animal to use the tonic."
	if applied:
		bag.remove_from_slot(slot, 1)
	_busy = false
	return {"ok": true} if applied else {"ok": false, "error": error if not error.is_empty() else "This booster cannot be applied."}
