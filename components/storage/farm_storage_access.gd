class_name FarmStorageAccess
extends ShopMerchant
## Invisible doorway interaction; the parent Barn owns its visuals and collisions.
@export var storage_id: String = "produce_warehouse"
var world: FarmWorld

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
	return InteractionTarget.new(self, InteractionTarget.Kind.MERCHANT, player).reachable_from(player.global_position)

func open_shop(player: FarmPlayer) -> bool:
	return super.open_shop(player) if world != null and world.storages.available() and can_reach(player) else false
