class_name InventorySlot
extends TextureButton
var _selection_frame: TextureRect
const NORMAL: Texture2D = preload("res://resources/ui/hotbar_slot.tres")
const SELECTED: Texture2D = preload("res://resources/ui/hotbar_selected.tres")
const FOCUS: Texture2D = preload("res://resources/ui/soil_focus.tres")
var inventory: InventoryComponent
var slot_index: int = 0
var compact: bool = false
var show_shortcut: bool = false
var _icon: TextureRect
var _count: Label

func _ready() -> void:
	custom_minimum_size = Vector2(52, 56) if compact else Vector2(78, 84)
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	texture_normal = NORMAL
	texture_pressed = SELECTED
	texture_hover = SELECTED
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: float = 10.0 if compact else 15.0
	_icon.offset_left = margin
	_icon.offset_top = 8.0 if compact else 12.0
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
	var shortcut: Label = Label.new()
	shortcut.name = "Shortcut"
	shortcut.text = str(slot_index + 1) if show_shortcut else ""
	shortcut.position = Vector2(6, 1)
	shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shortcut.add_theme_font_size_override("font_size", 14 if compact else 16)
	shortcut.add_theme_color_override("font_color", Color(0.28, 0.18, 0.12))
	add_child(shortcut)
	_count = Label.new()
	_count.name = "Count"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_font_size_override("font_size", 16 if compact else 20)
	_count.add_theme_color_override("font_color", Color(1, 0.95, 0.80))
	_count.add_theme_color_override("font_shadow_color", Color(0.28, 0.18, 0.12))
	_count.add_theme_constant_override("shadow_offset_x", 1)
	_count.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_count.offset_top = -22 if compact else -28
	_count.offset_right = -7
	_count.offset_bottom = -5
	inventory.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var item: ItemDefinition = inventory.get_slot_item(slot_index)
	var count: int = inventory.get_slot_count(slot_index)
	_icon.texture = item.icon if item != null else null
	_count.text = str(count) if count > 1 else ""
	tooltip_text = tr(item.display_name) if item != null else tr("Empty slot")
	if item != null and not item.description.is_empty():
		tooltip_text += "\n" + tr(item.description)

func _get_drag_data(_at_position: Vector2) -> Variant:
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
	_selection_frame.visible = value

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
