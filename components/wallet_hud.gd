class_name WalletHUD
extends CanvasLayer
## Container layout with the shared HUD skin, updated only on wallet changes.
var wallet: WalletComponent
var label: Label
var panel: PanelContainer

func _ready() -> void:
	layer = 12
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	panel.theme = preload("res://resources/ui/cozy_hud/theme.tres")
	panel.theme_type_variation = &"WalletPanel"
	margin.add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	wallet.changed.connect(_refresh)
	_refresh(wallet.balance)

func _refresh(balance: int) -> void:
	label.text = tr("{coins} coins").format({"coins": GameText.grouped_integer(balance)})

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh(wallet.balance)
