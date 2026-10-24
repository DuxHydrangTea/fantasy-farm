class_name ObjectiveTracker
extends Node
## World-owned commit adapters. No inventory-delta inference or UI dependencies.
var world: FarmWorld
var progress: ObjectiveProgress

func setup() -> void:
	if progress != null:
		return
	progress = ObjectiveProgress.new(world.player.wallet, _query)
	world.farming.action_committed.connect(_farming_commit)
	world.player.state.trough_interaction.refill_committed.connect(progress.record)
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		if world.is_ancestor_of(node) and (node as ShopMerchant).menu is ProduceSalesUI:
			var menu: ProduceSalesUI = (node as ShopMerchant).menu as ProduceSalesUI
			menu.visit_started.connect(_connect_sale.bind(menu))
	world.land.state.changed.connect(progress.refresh_state)
	# Ownership can change through purchase, sale, death or offline catch-up.
	var refresh: Timer = Timer.new()
	refresh.wait_time = 0.25
	refresh.timeout.connect(progress.refresh_state)
	add_child(refresh)
	refresh.start()

func _connect_sale(menu: ProduceSalesUI) -> void:
	menu.service.sold.connect(_sold)

func _farming_commit(condition: StringName, amount: int) -> void:
	progress.record(condition, amount)
	progress.refresh_state()

func _sold(quantity: int, _total: int) -> void:
	progress.record(&"sell_produce", quantity)

func _query(condition: StringName) -> int:
	if condition == &"prepared_soil":
		for row: Dictionary in world.farming.capture_soil():
			if world.land.state.is_unlocked(Vector2i(int(row.cell[0]), int(row.cell[1]))):
				return 1
		return 0
	if condition == &"land_columns":
		return world.land.state.unlocked_columns - world.land.state.starting_columns + 1
	if condition == &"own_animal":
		for child: Node in world.get_children():
			if child is AnimalPen:
				for actor: Node in child.get_children():
					if actor is AnimalActor and not actor.is_queued_for_deletion() and not (actor as AnimalActor).is_dead() and not (actor as AnimalActor).growth.is_dead():
						return 1
	return 0
