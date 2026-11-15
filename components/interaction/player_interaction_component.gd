class_name PlayerInteractionComponent
extends Node
## Điều phối tương tác bằng phím và nhấp chuột của người chơi.
##
## Mục tiêu được nhấp ngoài tầm được giữ trong [member pending] trong lúc
## điều hướng. Khi đến nơi, component kiểm tra lại mục tiêu và tầm trước khi
## thực hiện để tránh hành động với trạng thái đã thay đổi.

## Phát khi thời hạn hoặc nội dung phản hồi tương tác thay đổi.
signal feedback_changed
## Người chơi thực hiện tương tác.
var player: FarmPlayer
## Bộ tìm và xếp hạng mục tiêu.
var resolver: InteractionResolver
## Bộ hiển thị mục tiêu và phản hồi.
var presenter: InteractionPresenter
## Mục tiêu hiện được hiển thị.
var focused: InteractionTarget
## Mục tiêu đã nhấp đang chờ người chơi đi đến.
var pending: InteractionTarget
var _generation: int = 0
var _elapsed: float = 0.0
var _feedback: String = ""
var _feedback_until: int = 0:
	set(value):
		_feedback_until = value
		feedback_changed.emit()

func _ready() -> void:
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	if farm != null:
		farm.crop_lost.connect(_crop_lost)
	resolver = InteractionResolver.new(player)
	presenter = InteractionPresenter.new()
	presenter.player = player
	presenter.resolver = resolver
	add_child(presenter)
	player.state.navigation.focus_finished.connect(_arrived)
	player.state.navigation.focus_cancelled.connect(_cancelled)
	refresh()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if pending != null and not pending.valid():
		player.state.navigation.cancel()
	if _elapsed < 0.05:
		return
	_elapsed = 0.0
	if pending != null and player.state.navigation.is_navigating and player.state.navigation.focus_position.distance_to(pending.point()) > 12:
		var target: InteractionTarget = pending
		_navigate(target)
	refresh()

## Chọn mục tiêu cần hiển thị và cập nhật presenter, ẩn mục tiêu khi mở menu.
func refresh() -> void:
	focused = null if player.selection.is_menu_open() else pending if pending != null and pending.valid() else resolver.resolve()
	presenter.show_target(focused, pending != null and player.state.navigation.is_navigating, _feedback if Time.get_ticks_msec() < _feedback_until else "")

## Hủy điều hướng và thực hiện mục tiêu có thể chạm tới theo hướng nhìn.
## Trả true cả khi không có mục tiêu để đánh dấu input đã được xử lý.
func press() -> bool:
	player.state.navigation.cancel()
	focused = resolver.resolve()
	if focused == null:
		return true
	return execute(focused, &"harvest")

## Xử lý điểm nhấp toàn cục. Thực hiện ngay nếu trong tầm, nếu không thì
## điều hướng đến mục tiêu. Trả false khi không nhấp trúng mục tiêu nào.
func click(point: Vector2) -> bool:
	var target: InteractionTarget = resolver.clicked(point)
	if target == null:
		return false
	if target.reachable_from(player.global_position):
		player.state.navigation.cancel()
		player.animation.face(target.point() - player.global_position)
		execute(target)
	elif pending != null and pending.node == target.node and pending.kind == target.kind:
		# Click dồn cùng đối tượng giữ đường tiếp cận hiện có; tick sẽ theo đích di động.
		pending = target
		refresh()
		return true
	else:
		_navigate(target)
	refresh()
	return true

func _navigate(target: InteractionTarget) -> void:
	# Navigation already validates the full arrival tolerance around each goal.
	player.state.navigation.request_interaction(target.point(), target.reach(), target.reachable_from)
	pending = target
	_generation += 1

func _cancelled() -> void:
	_feedback = ""
	feedback_changed.emit()
	pending = null
	_generation += 1

func _arrived(reached: bool) -> void:
	if pending == null:
		return
	if not reached:
		pending = null
		_feedback = "Cannot reach that target."
		_feedback_until = Time.get_ticks_msec() + 1800
		return
	_complete_click.call_deferred(_generation)

func _complete_click(generation: int) -> void:
	if generation != _generation or pending == null or not pending.valid() or player.selection.is_menu_open():
		return
	var target: InteractionTarget = pending
	pending = null
	if target.reachable_from(player.global_position):
		player.animation.face(target.point() - player.global_position)
		execute(target)

## Thực hiện hành động theo loại mục tiêu sau khi kiểm tra menu, trạng thái và tầm.
## Có thể mở bảng, thu sản phẩm hoặc chuẩn bị hành động công cụ tương ứng.
## Trả false khi điều kiện chung không đạt hoặc loại mục tiêu không được xử lý.
func execute(target: InteractionTarget, _requested: StringName = &"") -> bool:
	if player.selection.is_menu_open() or player.state.current_state in [StateComponent.State.TOOL,StateComponent.State.WATER] or not target.reachable_from(player.global_position):
		return false
	match target.kind:
		InteractionTarget.Kind.TREE_PLOT_BOARD:
			return (target.node as TreePlotBoard).open_board(player)
		InteractionTarget.Kind.PEN_BOARD:
			return (target.node as PenBoard).open_board(player)
		InteractionTarget.Kind.ORDER_BOARD:
			return (target.node as OrderBoard).open_board(player)
		InteractionTarget.Kind.TREE:
			var tree: PerennialTree = target.node as PerennialTree
			if tree is FruitTree and tree.is_mature():
				return (player.get_parent() as FarmWorld).graft_menu.open_tree(tree as FruitTree)
			var tree_request: StringName = &""
			var action: StringName = player.tree_interaction.prepare_target(tree, tree_request)
			if action == &"tree_harvest":
				player.tree_interaction.harvest_now()
			elif action != &"blocked":
				player.state.active_action = action
				player.state.transition_to(StateComponent.State.WATER if action == &"tree_water" else StateComponent.State.TOOL)
			return true
		InteractionTarget.Kind.MERCHANT:
			if target.product != null and target.node is PenProduceAccess:
				return (target.node as PenProduceAccess).collect_product(player, target.product)
			return (target.node as ShopMerchant).open_shop(player)
		InteractionTarget.Kind.LAND:
			return (target.node as LandExpansionComponent).open_purchase(player)
		InteractionTarget.Kind.TROUGH:
			var action: StringName = player.state.trough_interaction.prepare_target(target.node as AnimalTrough)
			if action == &"blocked":
				return true
			player.state.active_action = action
			player.state.transition_to(StateComponent.State.WATER if action == &"refill_water" else StateComponent.State.TOOL)
			return true
		InteractionTarget.Kind.BEEHIVE:
			var hive: Beehive = target.node as Beehive
			if hive.apiary.world.honey_garden.inside(hive):
				return hive.apiary.world.honey_menu.open_hive(hive)
			if hive.collect(player.selection.inventory):
				Sound.play(&"collect_honey")
			return true
		InteractionTarget.Kind.ANIMAL:
			var animal: AnimalActor = target.node as AnimalActor
			var collected: int = animal.collect_produce(player.selection.inventory)
			if collected > 0:
				player.item_feedback.present_animal_collection(animal, collected)
				Sound.play(&"collect_milk" if animal.definition.species == AnimalTypes.Species.COW else &"collect_wool" if animal.definition.species == AnimalTypes.Species.SHEEP else &"collect_truffle" if animal.definition.species == AnimalTypes.Species.PIG else &"collect_egg")
			return true
		InteractionTarget.Kind.CROP:
			var crop: Crop = target.node as Crop
			if crop.conditions.weeds:
				player.state.boosters.prepare_weeding(crop)
				player.state.active_action = &"fertilize"
				player.state.transition_to(StateComponent.State.TOOL)
				return true
			if not crop.is_mature():
				_feedback = "Select pesticide and use it on this crop."
				_feedback_until = Time.get_ticks_msec() + 1800
				return true
			player.state.active_action = &"harvest"
			player.state.transition_to(StateComponent.State.TOOL)
			return true
		InteractionTarget.Kind.FLOWER:
			var action: StringName = player.state.flower_interaction.prepare_target(target.node as FlowerPot)
			if action != &"blocked":
				player.state.active_action = action
				player.state.transition_to(StateComponent.State.TOOL)
			return true
	return false

## Trả thông điệp nguồn còn hiệu lực, hoặc chuỗi rỗng sau khi hết hạn.
func feedback_source() -> String:
	return _feedback if Time.get_ticks_msec() < _feedback_until else ""

## Trả thời điểm hết hạn theo ticks mili giây, hoặc 0 khi không có phản hồi.
func feedback_expires_at() -> int:
	return _feedback_until if not _feedback.is_empty() else 0

func _crop_lost(inventory: InventoryComponent) -> void:
	if inventory == player.selection.inventory:
		_feedback = "Crop lost to pests or weeds."
		_feedback_until = Time.get_ticks_msec() + 1800
