class_name TouchQuantityComponent
extends Node
## Large +/- controls avoid a phone keyboard and tiny SpinBox arrows.
var quantity: SpinBox
var layout_root: Control
var decrease: Button
var increase: Button
var _empty_arrows: ImageTexture

static func attach(spin: SpinBox, ui_root: Control) -> void:
	var component: TouchQuantityComponent = TouchQuantityComponent.new()
	component.quantity = spin
	component.layout_root = ui_root
	spin.add_child(component)

static func refresh_for(spin: SpinBox) -> void:
	for child: Node in spin.get_children():
		if child is TouchQuantityComponent:
			(child as TouchQuantityComponent).refresh()

func _ready() -> void:
	_empty_arrows = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	decrease = _button("−", -1)
	increase = _button("+", 1)
	var row: Node = quantity.get_parent()
	row.move_child(decrease, quantity.get_index())
	row.move_child(increase, quantity.get_index() + 1)
	layout_root.resized.connect(refresh)
	quantity.value_changed.connect(_value_changed)
	quantity.visibility_changed.connect(refresh)
	refresh()

func _button(caption: String, step: int) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_step.bind(step))
	quantity.get_parent().add_child(button)
	return button

func _step(direction: int) -> void:
	if quantity.editable:
		quantity.value = clampf(quantity.value + direction * quantity.step, quantity.min_value, quantity.max_value)
		# Checkout may call apply() in the same frame. Keep its text in sync now,
		# rather than allowing the old text to undo the just-tapped step.
		quantity.get_line_edit().text = str(int(quantity.value)) if quantity.rounded else str(quantity.value)

func _value_changed(_value: float) -> void:
	refresh()

func refresh() -> void:
	var touch: bool = MobileLayout.is_touch(get_viewport())
	decrease.visible = touch and quantity.visible
	increase.visible = touch and quantity.visible
	decrease.disabled = not quantity.editable or quantity.value <= quantity.min_value
	increase.disabled = not quantity.editable or quantity.value >= quantity.max_value
	decrease.tooltip_text = tr("Decrease quantity")
	increase.tooltip_text = tr("Increase quantity")
	var edit: LineEdit = quantity.get_line_edit()
	edit.virtual_keyboard_enabled = not touch
	edit.mouse_filter = Control.MOUSE_FILTER_IGNORE if touch else Control.MOUSE_FILTER_STOP
	edit.focus_mode = Control.FOCUS_NONE if touch else Control.FOCUS_ALL
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE if touch else Control.MOUSE_FILTER_STOP
	if touch:
		quantity.add_theme_icon_override("updown", _empty_arrows)
	else:
		quantity.remove_theme_icon_override("updown")

func _exit_tree() -> void:
	# Buttons belong to the checkout row, not to this component's subtree.
	if is_instance_valid(decrease):
		decrease.queue_free()
	if is_instance_valid(increase):
		increase.queue_free()
