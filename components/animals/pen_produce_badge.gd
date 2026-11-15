extends PanelContainer
## Bảng trên tòa nhà hiển thị tối đa bốn loại sản phẩm và sức chứa chuồng.

## Chuồng cung cấp dữ liệu kho.
var pen: AnimalPen
## Sản phẩm đại diện hiển thị khi kho trống.
var default_product: ItemDefinition
## Cho phép xác định sản phẩm được nhấp.
var selectable: bool = false
## Nhãn tổng số đã dùng, sức chứa và chỗ trống.
var counts: Label
## Thanh thể hiện mức sử dụng kho.
var meter: ProgressBar
var _chips: Array[PanelContainer] = []
var _amounts: Array[Label] = []
var _icons: Array[TextureRect] = []
var _products: Array[ItemDefinition] = []
var _fill: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * 0.5
	z_index = 5
	add_theme_stylebox_override("panel", FarmUI.box(Color("36271e"), 6, 5, Color("a68051")))
	var light: CanvasItemMaterial = CanvasItemMaterial.new()
	light.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = light

	var body: VBoxContainer = VBoxContainer.new()
	body.custom_minimum_size.x = 110
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 3)
	add_child(body)
	var products: GridContainer = GridContainer.new()
	products.columns = 2
	products.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	products.mouse_filter = Control.MOUSE_FILTER_IGNORE
	products.add_theme_constant_override("h_separation", 6)
	products.add_theme_constant_override("v_separation", 3)
	body.add_child(products)
	var chip_style: StyleBoxFlat = FarmUI.box(Color("534032"), 4, 2, Color("a68051"))
	var plain_style: StyleBoxEmpty = StyleBoxEmpty.new()
	for index: int in range(4):
		var chip: PanelContainer = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", chip_style if selectable else plain_style)
		products.add_child(chip)
		_chips.append(chip)
		var contents: HBoxContainer = HBoxContainer.new()
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		contents.add_theme_constant_override("separation", 2)
		chip.add_child(contents)
		var amount: Label = Label.new()
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount.add_theme_font_size_override("font_size", 16)
		amount.add_theme_color_override("font_color", Color("fff1ce"))
		contents.add_child(amount)
		_amounts.append(amount)
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(icon)
		_icons.append(icon)
		_products.append(null)

	counts = Label.new()
	counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counts.add_theme_font_size_override("font_size", 15)
	counts.add_theme_color_override("font_color", Color("fff1ce"))
	body.add_child(counts)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 8
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", FarmUI.box(Color("634c35"), 3, 0, Color("634c35")))
	_fill = FarmUI.box(Color("a7cc65"), 3, 0, Color("a7cc65"))
	meter.add_theme_stylebox_override("fill", _fill)
	body.add_child(meter)

	resized.connect(_place)
	pen.produce_storage.changed.connect(refresh)
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()

## Đọc lại kho, cập nhật biểu tượng, số lượng và thanh sức chứa.
## Khi kho đầy, thanh đổi màu để báo trạng thái.
func refresh() -> void:
	var used: int = pen.produce_storage.count()
	var capacity: int = pen.produce_storage.capacity
	var available: int = pen.produce_storage.free_space()
	counts.text = "%d/%d  ·  %s" % [used, capacity, tr("Free: {free}").format({"free": available})]
	meter.max_value = capacity
	meter.value = used
	_fill.bg_color = Color("ef8652") if available == 0 else Color("a7cc65")
	_fill.border_color = _fill.bg_color
	var items: Array = pen.produce_storage.capture()
	for index: int in range(_icons.size()):
		var item: ItemDefinition = null
		var amount: int = 0
		if index < items.size():
			item = pen.produce_storage.products[items[index].item].item
			amount = int(items[index].amount)
		elif index == 0:
			item = default_product
		_products[index] = item if amount > 0 else null
		_amounts[index].text = "%d ×" % amount
		_icons[index].texture = item.icon if item != null else null
		_chips[index].visible = item != null
	reset_size()
	_place()

## Tìm sản phẩm có hàng tại tọa độ toàn cục trên bảng có thể chọn.
## Trả về null nếu bảng ẩn, không cho chọn hoặc không có mục tại vị trí đó.
func product_at(point: Vector2) -> ItemDefinition:
	if not selectable or not is_visible_in_tree():
		return null
	for index: int in range(_chips.size()):
		var chip: Control = _chips[index]
		if _products[index] != null and Rect2(Vector2.ZERO, chip.size).has_point(chip.get_global_transform().affine_inverse() * point):
			return _products[index]
	return null

func _place() -> void:
	# Keep the badge on the facade where it fits the normal gameplay camera.
	var extent: Vector2 = size * scale
	position = Vector2(-extent.x * 0.5, -36 - extent.y).round()
