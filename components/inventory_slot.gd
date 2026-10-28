class_name InventorySlot
extends TextureButton
var _selection_frame: TextureRect
const NORMAL: Texture2D = preload("res://resources/ui/hotbar_slot.tres")
const SELECTED: Texture2D = preload("res://resources/ui/hotbar_selected.tres")
const FOCUS: Texture2D = preload("res://resources/ui/soil_focus.tres")
const HOTBAR_NORMAL: Texture2D = preload("res://assets/Ui/CozyHUD/slot_normal.png")
const HOTBAR_SELECTED: Texture2D = preload("res://assets/Ui/CozyHUD/slot_selected.png")
var _hotbar_frame: NinePatchRect
var hotbar_skin: bool = false
var cozy_skin: bool = false
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
	# Nine-patch slots keep their corner pixels fixed; legacy skins use textures.
	var framed: bool = hotbar_skin or cozy_skin
	texture_normal = null if framed else NORMAL
	texture_pressed = null if framed else SELECTED
	texture_hover = null if framed else SELECTED
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	if framed:
		_hotbar_frame = NinePatchRect.new()
		_hotbar_frame.name = "HotbarFrame"
		_hotbar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hotbar_frame.patch_margin_left = 8
		_hotbar_frame.patch_margin_top = 8
		_hotbar_frame.patch_margin_right = 8
		_hotbar_frame.patch_margin_bottom = 8
		add_child(_hotbar_frame)
		_hotbar_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_entered.connect(_refresh_hotbar_frame)
		mouse_exited.connect(_refresh_hotbar_frame)
		toggled.connect(_refresh_hotbar_frame.unbind(1))
		_refresh_hotbar_frame()
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
	_shortcut.add_theme_color_override("font_color", Color(0.28, 0.18, 0.12))
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
	_count.add_theme_font_size_override("font_size", 18 if cozy_skin else 16 if compact else 20)
	style_count(_count)
	var count_style: StyleBoxFlat = StyleBoxFlat.new()
	count_style.bg_color = Color.TRANSPARENT
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
	_count.text = _format_count(count) if count > 1 else ""
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

static func style_count(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.80))
	label.add_theme_color_override("font_outline_color", Color(0.20, 0.10, 0.06))
	label.add_theme_color_override("font_shadow_color", Color(0.28, 0.18, 0.12))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _format_count(count: int) -> String:
	if not cozy_skin or count < 1000:
		return str(count)
	var whole: int = count / 1000
	var decimal: int = (count % 1000) / 100
	return str(whole) + ("," + str(decimal) if decimal > 0 else "") + "K"

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
	_refresh_hotbar_frame()
	_selection_frame.visible = value and not (hotbar_skin or cozy_skin)
	self_modulate = Color.WHITE if value or hotbar_skin or cozy_skin else Color(0.87, 0.84, 0.77)

func _refresh_hotbar_frame() -> void:
	if _hotbar_frame != null:
		_hotbar_frame.texture = HOTBAR_SELECTED if button_pressed or is_hovered() else HOTBAR_NORMAL

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
