class_name InteractionPresenter
extends CanvasLayer
## One context badge and one outline overlay. Original materials stay scene-owned.
var player: FarmPlayer
var resolver: InteractionResolver
var root: Control
var badge: PanelContainer
var label: Label
var outline: Sprite2D
var _range: BeehiveRangeDisplay
var _material: ShaderMaterial
var keycap: Label
var _hotbar: HotbarUI

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
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/interaction_outline.gdshader")
	clear()

func clear() -> void:
	if is_instance_valid(_range):
		_range.hide()
	if is_instance_valid(badge):
		badge.hide()
	if is_instance_valid(outline):
		outline.hide()

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
	if not is_instance_valid(outline):
		outline = Sprite2D.new()
		outline.name = "InteractionOutline"
		outline.material = _material
		outline.z_index = 1
		sprite.add_child(outline)
	elif outline.get_parent() != sprite:
		outline.reparent(sprite,false)
	outline.transform = Transform2D.IDENTITY
	outline.texture = texture
	outline.flip_h = bool(sprite.get("flip_h"))
	outline.flip_v = bool(sprite.get("flip_v"))
	outline.offset = Vector2(sprite.get("offset"))
	outline.centered = bool(sprite.get("centered"))
	outline.region_enabled = sprite is Sprite2D and (sprite as Sprite2D).region_enabled
	var uv_rect: Rect2 = Rect2(0,0,1,1)
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		uv_rect = Rect2(atlas.region.position / atlas.atlas.get_size(), atlas.region.size / atlas.atlas.get_size())
	elif outline.region_enabled:
		outline.region_rect = (sprite as Sprite2D).region_rect
		uv_rect = Rect2(outline.region_rect.position / texture.get_size(),outline.region_rect.size / texture.get_size())
	_material.set_shader_parameter("frame_uv",Vector4(uv_rect.position.x,uv_rect.position.y,uv_rect.end.x,uv_rect.end.y))
	outline.show()
	var action: String = target.action_text()
	keycap.text = GameText.action_key(player.state.action_harvest)
	keycap.visible = not walking
	label.text = tr("Walking to: {action}").format({"action":action}) if walking else action
	if not feedback.is_empty():
		label.text += "\n" + tr(feedback)
	var text_width: float = 96.0
	var font: Font = label.get_theme_font(&"font")
	for line: String in label.text.split("\n"):
		text_width = maxf(text_width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x + 2)
	label.custom_minimum_size.x = minf(root.size.x - 100.0, minf(text_width,360.0))
	badge.reset_size()
	var local_rect: Rect2 = resolver.visual_rect(target)
	var world_anchor: Vector2 = sprite.to_global(Vector2(local_rect.get_center().x,local_rect.position.y))
	var screen: Vector2 = player.get_canvas_transform() * world_anchor / scale
	var position: Vector2 = screen - Vector2(badge.size.x * 0.5,badge.size.y + 12)
	badge.position = _place_badge(position,screen).round()
	badge.show()

func _place_badge(preferred: Vector2, anchor: Vector2) -> Vector2:
	var occupied: Array[Rect2] = []
	if is_instance_valid(_hotbar) and _hotbar.root.visible:
		occupied.append(_ui_rect(_hotbar.slots.get_parent() as Control,_hotbar).grow(8))
	var inspector: AnimalInfoPanel = player.context_bars.animal_info
	if inspector.root.visible:
		occupied.append(_ui_rect(inspector.title.get_parent().get_parent() as Control,inspector).grow(6))
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
	return Rect2(rect.position * factor,rect.size * factor)

func _exit_tree() -> void:
	clear()
	if is_instance_valid(outline):
		outline.free()
