class_name InventorySlot
extends TextureButton
var _selection_frame: TextureRect
const NORMAL: Texture2D = preload("res://resources/ui/hotbar_slot.tres")
const SELECTED: Texture2D = preload("res://resources/ui/hotbar_selected.tres")
const FOCUS: Texture2D = preload("res://resources/ui/soil_focus.tres")
const HOTBAR_NORMAL: Texture2D = preload("res://resources/ui/hotbar_frame_normal.tres")
const HOTBAR_SELECTED: Texture2D = preload("res://resources/ui/hotbar_frame_selected.tres")
var hotbar_skin: bool = false
var inventory: InventoryComponent
var slot_index: int = 0
var compact: bool = false
var show_shortcut: bool = false
var _icon: TextureRect
var _count: Label
var _star: Label
var _shortcut: Label
const BADGE_SILVER: Texture2D = preload("res://assets/Icons/quality/badge_silver.png")
const BADGE_GOLD: Texture2D = preload("res://assets/Icons/quality/badge_gold.png")
var _quality_badge: TextureRect

func _ready() -> void:
	custom_minimum_size = Vector2(52, 56) if compact else Vector2(64, 68)
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	texture_normal = HOTBAR_NORMAL if hotbar_skin else NORMAL
	texture_pressed = HOTBAR_SELECTED if hotbar_skin else SELECTED
	texture_hover = HOTBAR_SELECTED if hotbar_skin else SELECTED
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: float = 10.0
	_icon.offset_left = margin
	_icon.offset_top = 8.0 if compact else 10.0
	_icon.offset_right = -margin
	_icon.offset_bottom = -12.0 if compact else -18.0
	_selection_frame = TextureRect.new()
	_selection_frame.name = "SelectionFrame"
	_selection_frame.texture = FOCUS
	_selection_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selection_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selection_frame)
	_selection_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_frame.hide()
	_shortcut = Label.new()
	_shortcut.name = "Shortcut"
	_shortcut.text = str(slot_index + 1) if show_shortcut else ""
	_shortcut.position = Vector2(6, 1)
	_shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcut.add_theme_font_size_override("font_size", 14 if compact else 16)
	_shortcut.add_theme_color_override("font_color", Color(0.9, 0.9, 0.96) if hotbar_skin else Color(0.28, 0.18, 0.12))
	add_child(_shortcut)
	_star = Label.new()
	_star.text = "*"
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star.add_theme_font_size_override("font_size", 22)
	_star.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	_star.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.04))
	_star.add_theme_constant_override("shadow_offset_x", 1)
	_star.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_star)
	_count = Label.new()
	_count.name = "Count"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_font_size_override("font_size", 16 if compact else 20)
	_count.add_theme_color_override("font_color", Color(1, 0.95, 0.80))
	_count.add_theme_color_override("font_shadow_color", Color(0.12,0.10,0.16) if hotbar_skin else Color(0.28,0.18,0.12))
	_count.add_theme_constant_override("shadow_offset_x", 1)
	_count.add_theme_constant_override("shadow_offset_y", 1)
	var count_style: StyleBoxFlat = StyleBoxFlat.new()
	count_style.bg_color = Color.TRANSPARENT if hotbar_skin else Color(0.20, 0.16, 0.10, 0.92)
	count_style.content_margin_left = 3
	count_style.content_margin_right = 3
	_count.add_theme_stylebox_override("normal", count_style)
	add_child(_count)
	_quality_badge = TextureRect.new()
	_quality_badge.name = "QualityBadge"
	_quality_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quality_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_quality_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_quality_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_quality_badge.custom_minimum_size = Vector2(16, 16)
	_quality_badge.size = Vector2(16, 16)
	add_child(_quality_badge)
	_count.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	resized.connect(_place_count)
	inventory.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var item: ItemDefinition = inventory.get_slot_item(slot_index)
	var count: int = inventory.get_slot_count(slot_index)
	_shortcut.visible = show_shortcut and not MobileLayout.is_touch(get_viewport())
	_icon.texture = item.icon if item != null else null
	_star.visible = item != null and item.star_fruit
	_count.text = str(count) if count > 1 else ""
	_count.visible = count > 1
	if _quality_badge != null:
		var highest_tier: int = 0
		if item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit:
			var slot_data: Dictionary = inventory.slot(slot_index)
			var tiers: Array = slot_data.get("tiers", [0, 0, 0])
			if tiers.size() > 2 and int(tiers[2]) > 0:
				highest_tier = 2
			elif tiers.size() > 1 and int(tiers[1]) > 0:
				highest_tier = 1
		if highest_tier == 2:
			_quality_badge.texture = BADGE_GOLD
			_quality_badge.show()
		elif highest_tier == 1:
			_quality_badge.texture = BADGE_SILVER
			_quality_badge.show()
		else:
			_quality_badge.hide()
	_place_count()
	tooltip_text = tr(item.display_name) if item != null else tr("Empty slot")
	if item != null and item.star_fruit:
		tooltip_text += "\n" + tr("Star fruit: a separate Chef ingredient, not Gold quality.")
	if item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit:
		tooltip_text += "\n" + ItemQuality.summary(inventory.slot(slot_index).tiers)
	if item != null and not item.description.is_empty():
		tooltip_text += "\n" + tr(item.description)

func _place_count() -> void:
	_star.position = Vector2(size.x - 18, 0)
	if _quality_badge != null:
		_quality_badge.position = Vector2(4, size.y - 20)
	_count.reset_size()
	_count.position = size - _count.size - Vector2(6, 6)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if MobileLayout.is_touch(get_viewport()):
		return null # A swipe scrolls the bag; touch moves use its explicit Move button.
	var item: ItemDefinition = inventory.get_slot_item(slot_index)
	if item == null:
		return null
	var preview: TextureRect = TextureRect.new()
	preview.texture = item.icon
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_drag_preview(preview)
	return {"inventory": inventory, "slot": slot_index, "item_id": item.item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("inventory") != inventory or not data.get("slot") is int:
		return false
	var item: ItemDefinition = inventory.get_slot_item(data.slot)
	return data.slot != slot_index and item != null and item.item_id == data.get("item_id")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		inventory.move_slot(data.slot, slot_index)

func set_selected(value: bool) -> void:
	set_pressed_no_signal(value)
	_selection_frame.visible = value and not hotbar_skin
	self_modulate = Color.WHITE if value or hotbar_skin else Color(0.87, 0.84, 0.77)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
