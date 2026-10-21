class_name WeatherHUD
extends CanvasLayer
var manager: WeatherManager
var label: Label

func _ready() -> void:
	layer = 11
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UIScaleComponent.attach(self, root)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.position = Vector2(16, 16)
	root.add_child(margin)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = preload("res://resources/ui/game_theme.tres")
	margin.add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

func refresh(timestamp: float) -> void:
	var minutes: int = floori(fposmod(timestamp + WeatherSchedule.UTC_OFFSET, 86400.0) / 60.0)
	var titles: Array[String] = [tr("Sunny"), tr("Rainy"), tr("Cloudy"), tr("Windy")]
	label.text = "%02d:%02d · %s" % [minutes / 60, minutes % 60, titles[manager.current_weather]]
