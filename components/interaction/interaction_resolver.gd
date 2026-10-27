class_name InteractionResolver
extends RefCounted
## E: fixed priority, then nearest, then stable scene instance ID. Click: hit targets only.
var player: FarmPlayer
var _bounds: Dictionary[Texture2D, Rect2] = {}

func _init(customer: FarmPlayer) -> void:
	player = customer

func candidates() -> Array[InteractionTarget]:
	var result: Array[InteractionTarget] = []
	for group: StringName in [&"shop_merchants", &"land_expansions", &"animal_troughs", &"animal_status_targets", &"beehives", &"perennial_trees", &"order_boards", &"pen_boards", &"tree_plot_boards"]:
		for node: Node in player.get_tree().get_nodes_in_group(group):
			if not node is Node2D or not _same_world(node):
				continue
			if node is AnimalActor:
				var animal: AnimalActor = node as AnimalActor
				if animal.production.definition == null or animal.production.definition.collection_mode != AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION or animal.production.stored_amount <= 0:
					continue
			var kind: InteractionTarget.Kind = InteractionTarget.Kind.TREE if node is PerennialTree else InteractionTarget.Kind.MERCHANT if node is ShopMerchant else InteractionTarget.Kind.LAND if node is LandExpansionComponent else InteractionTarget.Kind.TROUGH if node is AnimalTrough else InteractionTarget.Kind.BEEHIVE if node is Beehive else InteractionTarget.Kind.ANIMAL
			if node is OrderBoard:
				kind = InteractionTarget.Kind.ORDER_BOARD
			if node is TreePlotBoard:
				kind = InteractionTarget.Kind.TREE_PLOT_BOARD
			if node is PenBoard:
				kind = InteractionTarget.Kind.PEN_BOARD
			result.append(InteractionTarget.new(node as Node2D, kind, player))
	return result

func _same_world(node: Node) -> bool:
	return node.get_viewport() == player.get_viewport() and player.get_parent().is_ancestor_of(node)

func _crop_candidates(point: Vector2, hover: bool) -> Array[InteractionTarget]:
	var result: Array[InteractionTarget] = []
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	if farm != null and farm.farmland != null:
		var center: Vector2i = farm.world_to_cell(point)
		var padding: int = 2 if hover else 0
		for y: int in range(-padding, padding + 1):
			for x: int in range(-padding, padding + 1):
				var crop: Crop = farm.get_crop(center + Vector2i(x,y))
				if crop != null:
					crop.refresh(farm.time_manager.now())
					if crop.is_mature():
						result.append(InteractionTarget.new(crop, InteractionTarget.Kind.CROP, player))
	for garden: Node in player.get_tree().get_nodes_in_group(&"flower_gardens"):
		if not _same_world(garden):
			continue
		for pot: FlowerPot in (garden as FlowerGarden).pots.values():
			if hover:
				if not pot.get_visual_rect().grow(2.0).has_point(pot.to_local(point)):
					continue
			elif pot.global_position.distance_to(point) > 36.0:
				continue
			pot.refresh(pot.garden.time_manager.now())
			if pot.is_mature():
				result.append(InteractionTarget.new(pot, InteractionTarget.Kind.FLOWER, player))
	return result

func resolve() -> InteractionTarget:
	var options: Array[InteractionTarget] = candidates()
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	var point: Vector2 = player.global_position + player.animation.facing_vector * 16.0
	if farm != null:
		point = farm.farmland.to_global(farm.farmland.map_to_local(player.farming_actions.get_focused_cell()))
	options.append_array(_crop_candidates(point, false))
	var best: InteractionTarget
	for candidate: InteractionTarget in options:
		if candidate.reachable_from(player.global_position, true) and _better(candidate,best,player.global_position):
			best = candidate
	return best

func clicked(point: Vector2) -> InteractionTarget:
	var options: Array[InteractionTarget] = candidates()
	options.append_array(_crop_candidates(point, true))
	var best: InteractionTarget
	for candidate: InteractionTarget in options:
		if candidate.valid() and hit(candidate, point) and _better(candidate,best,point):
			best = candidate
	return best

func _better(candidate: InteractionTarget, best: InteractionTarget, origin: Vector2) -> bool:
	if best == null or candidate.priority() < best.priority():
		return true
	if candidate.priority() != best.priority():
		return false
	var a: float = origin.distance_squared_to(candidate.point())
	var b: float = origin.distance_squared_to(best.point())
	return a < b or (is_equal_approx(a,b) and candidate.node.get_instance_id() < best.node.get_instance_id())

func texture(sprite: Node2D) -> Texture2D:
	if sprite is Sprite2D:
		return (sprite as Sprite2D).texture
	if sprite is AnimatedSprite2D:
		var animated: AnimatedSprite2D = sprite as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation):
			return animated.sprite_frames.get_frame_texture(animated.animation,animated.frame)
	return null

func visual_rect(target: InteractionTarget) -> Rect2:
	var visual: Node2D = target.sprite()
	if target.kind == InteractionTarget.Kind.FLOWER and visual != null:
		var pot: FlowerPot = target.node as FlowerPot
		var relative: Transform2D = visual.global_transform.affine_inverse() * pot.global_transform
		return relative * pot.get_visual_rect()
	var frame: Texture2D = texture(visual)
	if frame == null:
		return Rect2()
	if not _bounds.has(frame):
		var image: Image = frame.get_image()
		_bounds[frame] = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO, frame.get_size())
	var rect: Rect2 = _bounds[frame]
	var frame_size: Vector2 = frame.get_size()
	if visual is Sprite2D and (visual as Sprite2D).region_enabled:
		frame_size = (visual as Sprite2D).region_rect.size
		rect = Rect2(Vector2.ZERO, frame_size)
	if bool(visual.get("flip_h")):
		rect.position.x = frame_size.x - rect.end.x
	if bool(visual.get("flip_v")):
		rect.position.y = frame_size.y - rect.end.y
	rect.position += Vector2(visual.get("offset")) - (frame_size * 0.5 if bool(visual.get("centered")) else Vector2.ZERO)
	return rect

func hit(target: InteractionTarget, point: Vector2) -> bool:
	var visual: Node2D = target.sprite()
	return is_instance_valid(visual) and visual_rect(target).grow(2.0).has_point(visual.to_local(point))
