class_name InteractionPresenter
extends CanvasLayer
## Context badge for the current interaction target.
var player: FarmPlayer
var resolver: InteractionResolver
var root: Control
var badge: PanelContainer
var label: Label
var _range: BeehiveRangeDisplay
var keycap: Label
var _hotbar: HotbarUI
var _shown_node: Node2D
var _shown_kind: int = -1
var _entrance: Tween
var _plant_anchor: Vector2

func _ready() -> void:
	layer = 18
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	UIScaleComponent.attach(self,root)
	for child: Node in player.get_children():
		if child is HotbarUI:
			_hotbar = child as HotbarUI
			break
	badge = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13,0.10,0.06,0.94)
	style.border_color = Color(0.95,0.78,0.40,0.9)
	for edge: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_border_width(edge,1)
		style.set_content_margin(edge,6)
	badge.add_theme_stylebox_override("panel",style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	badge.add_child(row)
	keycap = Label.new()
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keycap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.add_theme_font_size_override("font_size", 18)
	keycap.add_theme_color_override("font_color", Color(0.20, 0.15, 0.08))
	var key_style: StyleBoxFlat = StyleBoxFlat.new()
	key_style.bg_color = Color(0.97, 0.85, 0.58)
	key_style.content_margin_left = 6
	key_style.content_margin_right = 6
	keycap.add_theme_stylebox_override("normal", key_style)
	row.add_child(keycap)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color(1,0.95,0.80))
	row.add_child(label)
	clear()

func clear() -> void:
	_shown_node = null
	_shown_kind = -1
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	_entrance = null
	if is_instance_valid(_range):
		_range.hide()
	if is_instance_valid(badge):
		badge.hide()

func show_target(target: InteractionTarget, walking: bool, feedback: String = "") -> void:
	if target == null or not target.valid() or player.selection.is_menu_open():
		clear()
		return
	if is_instance_valid(_range):
		_range.hide()
	if target.kind == InteractionTarget.Kind.BEEHIVE:
		_range = (target.node as Beehive).range_display
		_range.modulate.a = 0.35
		_range.show()
	var sprite: Node2D = target.sprite()
	var texture: Texture2D = resolver.texture(sprite)
	if sprite == null or texture == null:
		clear()
		return
	var action: String = target.action_text()
	keycap.text = GameText.action_key(player.state.action_harvest)
	keycap.visible = not walking and not MobileLayout.is_touch(get_viewport())
	label.text = tr("Walking to: {action}").format({"action":action}) if walking else action
	if not feedback.is_empty():
		label.text += "\n" + tr(feedback)
	var text_width: float = 96.0
	var font: Font = label.get_theme_font(&"font")
	for line: String in label.text.split("\n"):
		text_width = maxf(text_width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x + 2)
	label.custom_minimum_size.x = minf(root.size.x - 100.0, minf(text_width,360.0))
	badge.reset_size()
	var new_target: bool = not badge.visible or _shown_node != target.node or _shown_kind != target.kind
	var world_anchor: Vector2
	if target.kind in [InteractionTarget.Kind.CROP, InteractionTarget.Kind.FLOWER] and not new_target:
		world_anchor = target.node.to_global(_plant_anchor)
	else:
		var local_rect: Rect2 = resolver.visual_rect(target)
		world_anchor = sprite.to_global(Vector2(local_rect.get_center().x,local_rect.position.y))
		if target.kind in [InteractionTarget.Kind.CROP, InteractionTarget.Kind.FLOWER]:
			_plant_anchor = target.node.to_local(world_anchor)
	var screen: Vector2 = player.get_canvas_transform() * world_anchor / scale - root.position
	var position: Vector2 = screen - Vector2(badge.size.x * 0.5,badge.size.y + 12)
	badge.position = _place_badge(position,screen).round()
	badge.pivot_offset = Vector2(badge.size.x * 0.5, badge.size.y)
	_shown_node = target.node
	_shown_kind = target.kind
	badge.show()
	if new_target:
		_animate_entrance()

func _animate_entrance() -> void:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	badge.scale = Vector2(0.88, 0.88)
	badge.modulate.a = 0.0
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(badge, "modulate:a", 1.0, 0.12)
	_entrance.tween_property(badge, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entrance.chain().tween_property(badge, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _place_badge(preferred: Vector2, anchor: Vector2) -> Vector2:
	var occupied: Array[Rect2] = []
	if is_instance_valid(_hotbar) and _hotbar.root.visible:
		occupied.append(_ui_rect(_hotbar.slots.get_parent() as Control,_hotbar).grow(8))
	var world: FarmWorld = player.get_parent() as FarmWorld
	if world != null:
		if world.objective_ui != null and world.objective_ui.hud.is_visible_in_tree():
			occupied.append(_ui_rect(world.objective_ui.hud, world.objective_ui).grow(8))
		if world.tutorial_hints != null and world.tutorial_hints.button.is_visible_in_tree():
			occupied.append(_ui_rect(world.tutorial_hints.button, world.objective_ui).grow(8))
		if world.weather != null and world.weather.hud != null:
			var weather_hud: WeatherHUD = world.weather.hud
			if weather_hud.label.is_visible_in_tree():
				occupied.append(_ui_rect(weather_hud.label.get_parent() as Control, weather_hud).grow(8))
			if is_instance_valid(weather_hud.debug_toggle) and weather_hud.debug_toggle.is_visible_in_tree():
				occupied.append(_ui_rect(weather_hud.debug_toggle, weather_hud).grow(8))
			if is_instance_valid(weather_hud.debug_bar) and weather_hud.debug_bar.is_visible_in_tree():
				occupied.append(_ui_rect(weather_hud.debug_bar, weather_hud).grow(8))
	var choices: Array[Vector2] = [preferred, anchor + Vector2(-badge.size.x * 0.5,24), Vector2(8,preferred.y), Vector2(root.size.x-badge.size.x-8,preferred.y), Vector2(8,root.size.y-badge.size.y-128)]
	for rect: Rect2 in occupied:
		choices.append(Vector2(rect.end.x + 8,preferred.y))
		choices.append(Vector2(root.size.x-badge.size.x-8,rect.end.y + 8))
		choices.append(Vector2(8,rect.end.y + 8))
	var position: Vector2 = preferred
	for choice: Vector2 in choices:
		position = Vector2(clampf(choice.x,8,maxf(8,root.size.x-badge.size.x-8)),clampf(choice.y,8,maxf(8,root.size.y-badge.size.y-128)))
		var clear: bool = true
		for rect: Rect2 in occupied:
			if rect.intersects(Rect2(position,badge.size)):
				clear = false
				break
		if clear:
			return position
	return position

func _ui_rect(control: Control, canvas: CanvasLayer) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	var factor: Vector2 = canvas.scale / scale
	return Rect2(rect.position * factor - root.position,rect.size * factor)

func _exit_tree() -> void:
	clear()
