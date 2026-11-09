class_name WalletHUD
extends CanvasLayer
var wallet: WalletComponent
var label: Label
var panel: PanelContainer

func _ready() -> void:
	layer = 12
	var root: Control = Control.new()
	root.theme = preload("res://resources/ui/cozy_hud/inventory_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UIScaleComponent.attach(self, root)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.theme_type_variation = &"WalletPanel"
	row.add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	VisualValueRow.money(label)
	var settings_button: Button = Button.new()
	settings_button.name = "Settings"
	settings_button.text = "\u2699"
	settings_button.tooltip_text = tr("Settings")
	settings_button.custom_minimum_size = Vector2(48, 48)
	settings_button.add_theme_font_size_override("font_size", 22)
	settings_button.add_theme_stylebox_override("normal", FarmUI.box(Color("fff8e9"), 24, 8))
	settings_button.pressed.connect(func() -> void:
		var player: FarmPlayer = get_parent().get_parent() as FarmPlayer
		if player != null:
			player.get_node("FarmSettings").call("show_settings"))
	row.add_child(settings_button)
	wallet.changed.connect(_refresh)
	_refresh(wallet.balance)

func _refresh(balance: int) -> void:
	label.text = FarmUI.compact_number(balance)
	panel.tooltip_text = tr("{coins} coins").format({"coins": GameText.grouped_integer(balance)})

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh(wallet.balance)
		var settings_button: Button = panel.get_parent().get_node("Settings") as Button
		settings_button.tooltip_text = tr("Settings")
