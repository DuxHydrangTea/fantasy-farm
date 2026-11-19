class_name InteractionResolver
extends RefCounted
## Chọn mục tiêu tương tác cho phím hành động hoặc vị trí nhấp trên thế giới.
## Mục tiêu cùng loại ưu tiên được so theo khoảng cách, rồi instance ID để
## kết quả ổn định trong scene. Nhấp chuột chỉ xét hình ảnh bị nhấp trúng.

## Người chơi dùng để giới hạn thế giới và xác định vị trí, hướng.
var player: FarmPlayer
var _bounds: Dictionary[Texture2D, Rect2] = {}

func _init(customer: FarmPlayer) -> void:
	player = customer

## Thu thập mục tiêu từ các nhóm scene cùng thế giới với người chơi.
## Vật nuôi chỉ được đưa vào khi có sản phẩm thu trực tiếp đang chờ.
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
					if crop.is_mature() or crop.conditions.affected():
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

func _tree_plot_candidates(origin: Vector2, clicked_mode: bool) -> Array[InteractionTarget]:
	var result: Array[InteractionTarget] = []
	if player == null:
		return result
	var world: FarmWorld = player.get_parent() as FarmWorld
	if world == null or world.trees == null or world.trees.plot_display == null:
		return result
	var plantation: TreePlantation = world.trees
	var display: TreePlotDisplay = plantation.plot_display
	for kind: TreeDefinition.Kind in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var region: Rect2i = TreePlantation.region_for(kind).grow(4)
		if not region.has_point(plantation.cell_for(origin)):
			continue
		var center_cell: Vector2i = plantation.planting_cell(origin, kind)
		if clicked_mode:
			if TreePlantation.valid_cell(center_cell, kind) and not plantation.trees.has(center_cell) and plantation.has_ground(center_cell) and TreePlantation.plot_hit_rect(plantation.point_for(center_cell)).has_point(origin):
				result.append(InteractionTarget.for_tree_plot(display, center_cell, kind, player))
		else:
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var plot_cell: Vector2i = center_cell + Vector2i(dx * 3, dy * 3)
					if TreePlantation.valid_cell(plot_cell, kind) and not plantation.trees.has(plot_cell) and plantation.has_ground(plot_cell):
						result.append(InteractionTarget.for_tree_plot(display, plot_cell, kind, player))
	return result

## Chọn mục tiêu trong tầm và hướng nhìn cho phím tương tác, hoặc null.
## Bổ sung cây trồng và chậu hoa quanh ô đang được nhắm.
func resolve() -> InteractionTarget:
	var options: Array[InteractionTarget] = candidates()
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	var point: Vector2 = player.global_position + player.animation.facing_vector * 16.0
	if farm != null:
		point = farm.farmland.to_global(farm.farmland.map_to_local(player.farming_actions.get_focused_cell()))
	options.append_array(_crop_candidates(point, false))
	options.append_array(_tree_plot_candidates(player.global_position, false))
	var best: InteractionTarget
	for candidate: InteractionTarget in options:
		if candidate.reachable_from(player.global_position, true) and _better(candidate,best,player.global_position):
			best = candidate
	return best

## Chọn mục tiêu có hình ảnh chứa điểm toàn cục, hoặc null.
## Điểm chọn sản phẩm trên bảng kho chuồng được ưu tiên trực tiếp.
func clicked(point: Vector2) -> InteractionTarget:
	var options: Array[InteractionTarget] = candidates()
	options.append_array(_crop_candidates(point, true))
	options.append_array(_tree_plot_candidates(point, true))
	var best: InteractionTarget
	for candidate: InteractionTarget in options:
		if not candidate.valid():
			continue
		if candidate.node is PenProduceAccess:
			candidate.product = (candidate.node as PenProduceAccess).product_at(point)
			if candidate.product != null:
				return candidate
		if hit(candidate, point) and _better(candidate,best,point):
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

## Lấy texture của Sprite2D hoặc khung hiện tại của AnimatedSprite2D.
func texture(sprite: Node2D) -> Texture2D:
	if sprite is Sprite2D:
		return (sprite as Sprite2D).texture
	if sprite is AnimatedSprite2D:
		var animated: AnimatedSprite2D = sprite as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation):
			return animated.sprite_frames.get_frame_texture(animated.animation,animated.frame)
	return null

## Tính hình chữ nhật phần ảnh được dùng trong tọa độ node hình ảnh.
## Kết quả xét offset, căn giữa, lật và vùng ảnh; cache biên ảnh theo texture.
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

## Kiểm tra điểm toàn cục nằm trong vùng hình ảnh mục tiêu, có đệm hai đơn vị.
func hit(target: InteractionTarget, point: Vector2) -> bool:
	if target.kind == InteractionTarget.Kind.TREE_PLOT:
		return TreePlantation.plot_hit_rect(target.point()).has_point(point)
	var visual: Node2D = target.sprite()
	return is_instance_valid(visual) and visual_rect(target).grow(2.0).has_point(visual.to_local(point))
