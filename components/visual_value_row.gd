class_name VisualValueRow
extends HBoxContainer
## Hàng giao diện hiển thị biểu tượng, giá trị và tooltip tên hoặc chất lượng.

## Biểu tượng xu dùng cho giá trị tiền.
const COIN: Texture2D = preload("res://assets/Icons/currency/gold_coin.png")
## Huy hiệu chất lượng bạc.
const SILVER: Texture2D = preload("res://assets/Icons/quality/badge_silver.png")
## Huy hiệu chất lượng vàng.
const GOLD: Texture2D = preload("res://assets/Icons/quality/badge_gold.png")
## Ô hiển thị biểu tượng chính.
var icon: TextureRect
## Nhãn hiển thị số lượng hoặc mô tả.
var value: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 6)
	icon = make_icon(null)
	add_child(icon)
	value = Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 16)
	add_child(value)

## Tạo TextureRect giữ tỉ lệ ảnh, dùng lọc nearest và kích thước tối thiểu.
static func make_icon(texture: Texture2D, pixels: int = 24) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture = texture
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.custom_minimum_size = Vector2(pixels, pixels)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

## Đặt biểu tượng xu trước nhãn có sẵn bằng cách chuyển nhãn vào một hàng mới.
## Metadata trên nhãn ngăn việc bọc lặp lại khi gọi nhiều lần.
static func money(label: Label) -> void:
	if label.has_meta(&"coin_row"):
		return
	var parent: Node = label.get_parent()
	var index: int = label.get_index()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = label.name + "CoinRow"
	row.size_flags_horizontal = label.size_flags_horizontal
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	parent.move_child(row, index)
	row.add_child(make_icon(COIN, 20))
	label.reparent(row, false)
	# Ellipsized card labels have a zero minimum width; give the amount real space.
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_meta(&"coin_row", row)

## Tạo một hàng cùng node cha và đặt ngay trước nhãn đã cho.
static func before(label: Label) -> VisualValueRow:
	var row: VisualValueRow = VisualValueRow.new()
	label.get_parent().add_child(row)
	label.get_parent().move_child(row, label.get_index())
	return row

## Hiển thị biểu tượng, nội dung và tên đã dịch của vật phẩm.
## Cấp dương hiển thị huy hiệu chất lượng. Vật phẩm null ẩn toàn bộ hàng.
func show_item(item: ItemDefinition, text: String, tier: int = -1) -> void:
	icon.texture = item.icon if item != null else null
	value.text = text
	tooltip_text = TranslationServer.translate(item.display_name) if item != null else ""
	var badge: TextureRect = get_node_or_null("QualityBadge") as TextureRect
	if tier > 0:
		if badge == null:
			badge = make_icon(null, 18)
			badge.name = "QualityBadge"
			add_child(badge)
			move_child(badge, 1)
		badge.texture = SILVER if tier == 1 else GOLD
		badge.tooltip_text = ItemQuality.label(tier)
	if badge != null:
		badge.visible = tier > 0
	if tier >= 0:
		tooltip_text += " · " + ItemQuality.label(tier)
	visible = item != null

## Hiển thị số xu có phân nhóm chữ số cùng tooltip đã dịch.
func show_coins(amount: int) -> void:
	icon.texture = COIN
	value.text = GameText.grouped_integer(amount)
	tooltip_text = TranslationServer.translate("{coins} coins").format({"coins": value.text})
	show()

## Hiển thị sản phẩm và số lượng mỗi chu kỳ với chuỗi thời gian đã định dạng.
## Cấu hình thiếu hoặc không hợp lệ sẽ ẩn hàng.
func show_production(definition: AnimalProductionDefinition, duration: String) -> void:
	if definition == null or not definition.is_valid():
		hide()
		return
	show_item(definition.production_item, "× %s / %s" % [GameText.grouped_integer(definition.production_amount), duration])
