extends CanvasLayer
## Uses the inventory theme and container layout, updated only on wallet changes.
var wallet: WalletComponent
var label: Label

func _ready() -> void:
	layer = 12
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = preload("res://resources/ui/game_theme.tres")
	margin.add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	wallet.changed.connect(_refresh)
	_refresh(wallet.balance)

func _refresh(balance: int) -> void:
	label.text = "%d xu" % balance
