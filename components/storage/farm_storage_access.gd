class_name FarmStorageAccess
extends ShopMerchant
## Invisible doorway interaction; the parent building owns its visuals and collisions.
@export var storage_id: String = "produce_warehouse"
var world: FarmWorld
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D

func _enter_tree() -> void:
	create_shop_ui = false
	super._enter_tree()
	if menu == null:
		var view: FarmStorageMenu = preload("res://scenes/storage/storage_menu.tscn").instantiate() as FarmStorageMenu
		view.storage_id = storage_id
		menu = view
		add_child(menu)
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is FarmWorld:
		ancestor = ancestor.get_parent()
	world = ancestor as FarmWorld
	if world != null:
		world.storage_accesses[storage_id] = self

func interaction_sprite() -> Node2D:
	return get_parent().get_node_or_null("Sprite2D") as Node2D

func interaction_action_text() -> String:
	return tr("Open storage")

func can_reach(player: FarmPlayer) -> bool:
	if not is_instance_valid(player) or not is_inside_tree() or not is_visible_in_tree():
		return false
	if interaction_area == null or interaction_shape == null or interaction_shape.disabled or interaction_shape.shape == null:
		return false
	# Test the actual feet against the scene-owned Area shape, including immediately
	# after a teleport/load, before the physics server refreshes its overlap cache.
	var feet: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet == null or feet.disabled or feet.shape == null:
		return false
	if not interaction_shape.shape.collide(interaction_shape.global_transform, feet.shape, feet.global_transform):
		return false
	var exclusions: Array[RID] = [player.get_rid()]
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position, interaction_position(), 1, exclusions)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func is_within_interaction_range(customer: FarmPlayer) -> bool:
	return can_reach(customer)

func open_shop(player: FarmPlayer) -> bool:
	return super.open_shop(player) if world != null and world.storages.available() and can_reach(player) else false
