class_name WalletHUD
extends CanvasLayer
## Uses the inventory theme and container layout, updated only on wallet changes.
var wallet: WalletComponent
var label: Label
var panel: PanelContainer

func _ready() -> void:
	layer = 12
	var root: Control = Control.new()
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
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = preload("res://resources/ui/game_theme.tres")
	margin.add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	wallet.changed.connect(_refresh)
	_refresh(wallet.balance)

func _refresh(balance: int) -> void:
	label.text = tr("{coins} coins").format({"coins": balance})

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh(wallet.balance)
