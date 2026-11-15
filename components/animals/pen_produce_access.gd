class_name PenProduceAccess
extends ShopMerchant
## Điểm tương tác thu sản phẩm của chuồng qua phím hoặc nhấp chuột.
## Bộ phân giải tương tác dùng hình tòa nhà để xác định mục tiêu hiển thị.

## Chuồng sở hữu kho sản phẩm.
var pen: AnimalPen
## Tòa nhà được dùng làm hình tương tác.
var building: Node2D
## Sản phẩm đại diện khi kho trống.
var default_product: ItemDefinition
## Cho phép chọn từng sản phẩm trên bảng trạng thái.
var choose_product: bool = false
## Bảng trạng thái sản phẩm được tạo khi node sẵn sàng.
var badge: PanelContainer

func _enter_tree() -> void:
	create_shop_ui = false
	super._enter_tree()

func _ready() -> void:
	super._ready()
	badge = preload("res://components/animals/pen_produce_badge.gd").new()
	badge.name = "ProduceStatus"
	badge.pen = pen
	badge.default_product = default_product
	badge.selectable = choose_product
	add_child(badge)

## Lấy Sprite2D của tòa nhà nếu tòa nhà còn hợp lệ.
func interaction_sprite() -> Node2D:
	return building.get_node_or_null("Sprite2D") as Node2D if is_instance_valid(building) else null

## Trả về nhãn hành động đã dịch theo chế độ thu.
func interaction_action_text() -> String:
	return tr("Collect all produce") if choose_product else tr("Collect produce")

## Xử lý giao diện tương tác chung bằng thao tác thu sản phẩm.
func open_shop(customer: FarmPlayer) -> bool:
	return collect_product(customer)

## Trả về sản phẩm tại vị trí toàn cục trên bảng, hoặc null.
func product_at(point: Vector2) -> ItemDefinition:
	return badge.product_at(point)

## Đồng bộ thời gian rồi chuyển sản phẩm từ kho chuồng vào túi người chơi.
## Có thể lọc theo sản phẩm. Trả false nếu ngoài tầm hoặc menu đang mở,
## còn lại hiển thị kết quả và trả true kể cả khi kho trống hoặc túi đầy.
func collect_product(customer: FarmPlayer, product: ItemDefinition = null) -> bool:
	if not is_within_interaction_range(customer) or customer.selection.is_menu_open():
		return false
	var clock: FarmClock = customer.farming_actions.get_farming_controller().time_manager
	var item_id: StringName = product.item_id if product != null else &""
	var moved: int = pen.collect_stored_produce(customer.selection.inventory, clock.now(), item_id)
	var has_stock: bool = pen.produce_storage.products.has(String(item_id)) if product != null else pen.produce_storage.count() > 0
	_present_result(moved, has_stock)
	return true

func _present_result(moved: int, has_stock: bool) -> void:
	if moved > 0:
		bubble_text.text = tr("Collected: {amount}").format({"amount": moved})
	else:
		bubble_text.text = tr("Inventory full") if has_stock else tr("No products ready")
	bubble.reset_size()
	_place_bubble()
	bubble.show()
	bubble_timer.start(1.8)
