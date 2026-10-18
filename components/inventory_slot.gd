extends TextureButton
const Inventory = preload("res://components/inventory_component.gd")
const NORMAL: Texture2D = preload("res://resources/ui/hotbar_slot.tres")
const SELECTED: Texture2D = preload("res://resources/ui/hotbar_selected.tres")
const FOCUS: Texture2D = preload("res://resources/ui/soil_focus.tres")
var inventory: Inventory
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
	var frame: TextureRect = TextureRect.new()
	frame.name = "SelectionFrame"
	frame.texture = FOCUS
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.hide()
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
	var stack: Dictionary = inventory.slot(slot_index)
	_icon.texture = stack.item.icon if stack.item != null else null
	_count.text = str(stack.count) if stack.count > 1 else ""
	tooltip_text = stack.item.display_name if stack.item != null else "Ô trống"

func _get_drag_data(_at_position: Vector2) -> Variant:
	var stack: Dictionary = inventory.slot(slot_index)
	if stack.item == null:
		return null
	var preview: TextureRect = TextureRect.new()
	preview.texture = stack.item.icon
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_drag_preview(preview)
	return {"inventory": inventory, "slot": slot_index, "item_id": stack.item.item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("inventory") != inventory or not data.get("slot") is int:
		return false
	var stack: Dictionary = inventory.slot(data.slot)
	return data.slot != slot_index and stack.item != null and stack.item.item_id == data.get("item_id")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		inventory.move_slot(data.slot, slot_index)
