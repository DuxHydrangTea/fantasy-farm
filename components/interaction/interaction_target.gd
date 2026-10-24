class_name InteractionTarget
extends RefCounted
## A typed, short-lived view of a scene target. IDs/node names never drive behavior.
enum Kind { MERCHANT, LAND, TROUGH, ANIMAL, CROP, FLOWER, BEEHIVE, TREE, ORDER_BOARD, PEN_BOARD }
var node: Node2D
var kind: Kind
var player: FarmPlayer

func _init(target: Node2D, type: Kind, customer: FarmPlayer) -> void:
	node = target
	kind = type
	player = customer

func valid() -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree() or not node.is_visible_in_tree():
		return false
	match kind:
		Kind.PEN_BOARD:
			return is_instance_valid((node as PenBoard).pen) and (node as PenBoard).pen.is_visible_in_tree()
		Kind.LAND:
			return (node as LandExpansionComponent).sign != null and (node as LandExpansionComponent).sign.visible
		Kind.ANIMAL:
			var animal: AnimalActor = node as AnimalActor
			return not animal.is_dead() and animal.production.definition != null and animal.production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION and animal.production.stored_amount > 0
		Kind.CROP:
			return not (node as Crop).is_retiring() and (node as Crop).is_mature()
		Kind.FLOWER:
			return (node as FlowerPot).is_mature()
		Kind.TREE:
			return not (node as PerennialTree).removed
	return true

func priority() -> int:
	return 0 if kind in [Kind.MERCHANT, Kind.LAND, Kind.ORDER_BOARD, Kind.PEN_BOARD] else 1 if kind in [Kind.TROUGH,Kind.BEEHIVE] else 2 if kind == Kind.ANIMAL else 3

func reach() -> float:
	return 48.0 if kind == Kind.MERCHANT else 30.0 if kind == Kind.TROUGH else 20.0 if kind == Kind.CROP else 28.0 if kind == Kind.FLOWER else 32.0

func point() -> Vector2:
	if kind == Kind.MERCHANT:
		return (node as ShopMerchant).interaction_position()
	if kind == Kind.LAND:
		return (node as LandExpansionComponent).interaction_position()
	if kind == Kind.CROP:
		var farm: FarmingController = player.farming_actions.get_farming_controller()
		var local: Vector2 = farm.farmland.to_local(node.global_position) - Vector2(0, farm.farmland.tile_set.tile_size.y * 0.5)
		return farm.farmland.to_global(farm.farmland.map_to_local(farm.farmland.local_to_map(local)))
	return node.global_position

func sprite() -> Node2D:
	match kind:
		Kind.MERCHANT: return (node as ShopMerchant).interaction_sprite()
		Kind.LAND: return (node as LandExpansionComponent).sign
		Kind.BEEHIVE: return (node as Beehive).sprite
		Kind.TROUGH: return (node as AnimalTrough).sprite
		Kind.ANIMAL: return (node as AnimalActor).sprite
		Kind.CROP: return (node as Crop).sprite
		Kind.FLOWER: return (node as FlowerPot).sprite
		Kind.TREE: return (node as PerennialTree).sprite
		Kind.ORDER_BOARD: return (node as OrderBoard).sprite
		Kind.PEN_BOARD: return (node as PenBoard).sprite
	return null

func reachable_from(position: Vector2, facing: bool = false) -> bool:
	if not valid() or position.distance_to(point()) > reach():
		return false
	var offset: Vector2 = point() - position
	if facing and not offset.is_zero_approx() and offset.normalized().dot(player.animation.facing_vector) < 0.35:
		return false
	var exclusions: Array[RID] = [player.get_rid()]
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(position, point(), 1, exclusions)
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != node:
		return false
	if kind == Kind.CROP:
		var farm: FarmingController = player.farming_actions.get_farming_controller()
		var offset_cell: Vector2i = farm.world_to_cell(point()) - farm.world_to_cell(position)
		var direction: Vector2i = Vector2i(signi(offset_cell.x), 0) if absf(offset.x) > absf(offset.y) else Vector2i(0, signi(offset_cell.y))
		return absi(offset_cell.x) + absi(offset_cell.y) == 1 and offset_cell == direction
	return true

func action_text() -> String:
	match kind:
		Kind.PEN_BOARD: return tr("Manage pen")
		Kind.ORDER_BOARD: return tr("View orders")
		Kind.MERCHANT:
			return tr("Sell produce") if (node as ShopMerchant).menu is ProduceSalesUI else tr("Trade")
		Kind.LAND:
			return tr("Reclaim next column ({coins} coins)").format({"coins": GameText.grouped_integer((node as LandExpansionComponent).state.next_price())})
		Kind.TROUGH:
			var trough: AnimalTrough = node as AnimalTrough
			var source: String = "Fill feed ({stock}/{capacity})" if trough.kind == AnimalTrough.Kind.FOOD else "Fill water ({stock}/{capacity})"
			var result: String = tr(source).format({"stock": trough.stock, "capacity": trough.capacity})
			var reason: String = player.state.trough_interaction.auto_hint(trough)
			return result if reason.is_empty() else result + "\n" + reason
		Kind.ANIMAL:
			var animal: AnimalActor = node as AnimalActor
			return tr("Collect produce") if animal.production.definition != null and animal.production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION and animal.production.stored_amount > 0 else tr("Inspect animal")
		Kind.BEEHIVE: return (node as Beehive).action_text()
		Kind.CROP: return tr("Harvest crop")
		Kind.FLOWER: return tr("Harvest flowers")
		Kind.TREE: return (node as PerennialTree).action_text(player.selection.get_selected_item())
	return ""
