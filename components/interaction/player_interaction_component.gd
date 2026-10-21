class_name PlayerInteractionComponent
extends Node
## Single E/click coordinator; explicit clicked targets stay pinned until arrival.
var player: FarmPlayer
var resolver: InteractionResolver
var presenter: InteractionPresenter
var focused: InteractionTarget
var pending: InteractionTarget
var _generation: int = 0
var _elapsed: float = 0.0
var _feedback: String = ""
var _feedback_until: int = 0

func _ready() -> void:
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

func refresh() -> void:
	focused = null if player.selection.is_menu_open() else pending if pending != null and pending.valid() else resolver.resolve()
	presenter.show_target(focused, pending != null and player.state.navigation.is_navigating, _feedback if Time.get_ticks_msec() < _feedback_until else "")

func press() -> bool:
	player.state.navigation.cancel()
	focused = resolver.resolve()
	if focused == null:
		return true
	return execute(focused, &"harvest")

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

func execute(target: InteractionTarget, _requested: StringName = &"") -> bool:
	if player.selection.is_menu_open() or player.state.current_state in [StateComponent.State.TOOL,StateComponent.State.WATER] or not target.reachable_from(player.global_position):
		return false
	match target.kind:
		InteractionTarget.Kind.TREE:
			var tree: PerennialTree = target.node as PerennialTree
			var tree_request: StringName = &"harvest" if tree is FruitTree and tree.is_mature() else &""
			var action: StringName = player.tree_interaction.prepare_target(tree, tree_request)
			if action == &"tree_harvest":
				player.tree_interaction.harvest_now()
			elif action != &"blocked":
				player.state.active_action = action
				player.state.transition_to(StateComponent.State.WATER if action == &"tree_water" else StateComponent.State.TOOL)
			return true
		InteractionTarget.Kind.MERCHANT:
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
			(target.node as Beehive).collect(player.selection.inventory)
			return true
		InteractionTarget.Kind.ANIMAL:
			var animal: AnimalActor = target.node as AnimalActor
			animal.set_status_focused(true)
			animal.collect_produce(player.selection.inventory)
			player.context_bars.animal_info.inspect(animal)
			return true
		InteractionTarget.Kind.CROP:
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

func feedback_source() -> String:
	return _feedback if Time.get_ticks_msec() < _feedback_until else ""
