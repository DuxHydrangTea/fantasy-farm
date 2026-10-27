class_name FarmStorageSlot
extends Button
## Presentation only: transfer commands always go through FarmStorageService.
var item: ItemDefinition
var amount: int = 0
var tiers: Array = [0, 0, 0]
var _icon: TextureRect
var _count: Label
var _badge: TextureRect

func _ready() -> void:
	toggle_mode = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 10
	_icon.offset_top = 8
	_icon.offset_right = -10
	_icon.offset_bottom = -16
	_count = Label.new()
	_count.name = "Count"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_font_size_override("font_size", 16)
	add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_count.offset_left = 4
	_count.offset_right = -6
	_count.offset_top = -24
	_count.offset_bottom = -4
	_badge = TextureRect.new()
	_badge.name = "QualityBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.position = Vector2(4, 4)
	_badge.size = Vector2(16, 16)
	add_child(_badge)
	refresh()

func refresh() -> void:
	_icon.texture = item.icon if item != null else null
	_count.text = str(amount) if item != null and amount > 1 else ""
	_count.visible = not _count.text.is_empty()
	var highest: int = 2 if int(tiers[2]) > 0 else (1 if int(tiers[1]) > 0 else 0)
	_badge.visible = item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit and highest > 0
	_badge.texture = InventorySlot.BADGE_GOLD if highest == 2 else InventorySlot.BADGE_SILVER
	tooltip_text = tr(item.display_name) if item != null else tr("Empty slot")
	if item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit:
		tooltip_text += "\n" + ItemQuality.summary(tiers)
