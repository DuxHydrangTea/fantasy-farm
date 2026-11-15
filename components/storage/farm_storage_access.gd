class_name FarmStorageAccess
extends ShopMerchant
## Điểm tương tác vô hình mở kho tại cửa tòa nhà.
## Tòa nhà cha sở hữu hình ảnh và va chạm; vùng cửa kiểm tra chân người chơi.

## Mã kho được mở bởi cửa này.
@export var storage_id: String = "produce_warehouse"
## Thế giới chứa dịch vụ kho và bảng điểm tương tác.
var world: FarmWorld
## Vùng tương tác tại cửa.
@onready var interaction_area: Area2D = $InteractionArea
## Hình va chạm của vùng tương tác.
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

## Lấy sprite của tòa nhà cha để xác định vùng nhấp.
func interaction_sprite() -> Node2D:
	return get_parent().get_node_or_null("Sprite2D") as Node2D

## Nhãn mở kho đã dịch.
func interaction_action_text() -> String:
	return tr("Open storage")

## Kiểm tra hình chân người chơi giao vùng cửa và đường nhìn không bị chặn.
## Kiểm tra hình trực tiếp để vẫn đúng ngay sau khi dịch chuyển hoặc tải game.
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

## Kiểm tra khách có thể tiếp cận cửa kho.
func is_within_interaction_range(customer: FarmPlayer) -> bool:
	return can_reach(customer)

## Mở menu kho khi dịch vụ sẵn sàng và người chơi ở trong tầm.
func open_shop(player: FarmPlayer) -> bool:
	return super.open_shop(player) if world != null and world.storages.available() and can_reach(player) else false
