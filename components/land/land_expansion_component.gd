class_name LandExpansionComponent
extends Node2D
## World presentation and interaction. Ownership and purchase rules live in state.
const DECOR: Texture2D = preload("res://assets/Outdoor decoration/Outdoor_Decor.png")
const WEED_REGIONS: Array[Rect2] = [Rect2(64, 336, 16, 16), Rect2(64, 352, 16, 16)]
const SIGNS: Texture2D = preload("res://assets/Outdoor decoration/Signs.png")
const REACH: float = 32.0
var state: LandExpansionState = LandExpansionState.new()
var farming: FarmingController
var player: FarmPlayer
var menu: LandPurchaseUI
var sign: Sprite2D
var prompt: Label
var _reveal_column: int = -1
var _revealed_rows: int = 0
var grass_cover: LandGrassCover = LandGrassCover.new()
var _clearing: Tween

func _ready() -> void:
	assert(farming != null and farming.farmland != null and player != null)
	transform = farming.farmland.transform
	z_index = -2
	add_to_group(&"land_expansions")
	menu = LandPurchaseUI.new()
	menu.expansion = self
	add_child(menu)
	sign = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = SIGNS
	atlas.region = Rect2(0, 0, 16, 16)
	sign.texture = atlas
	sign.z_index = 12
	add_child(sign)
	prompt = Label.new()
	prompt.text = "E"
	prompt.position = Vector2(-8, -28)
	prompt.scale = Vector2.ONE * 0.5
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 6)
	sign.add_child(prompt)
	state.changed.connect(_state_changed)
	_state_changed()

func interaction_position() -> Vector2:
	return to_global(farming.farmland.map_to_local(Vector2i(state.next_column(), LandExpansionState.REGION.position.y - 1)))

func can_interact(customer: FarmPlayer) -> bool:
	return customer == player and not state.is_complete() and _reveal_column < 0 and is_visible_in_tree() and customer.global_position.distance_to(interaction_position()) <= REACH

func open_purchase(customer: FarmPlayer) -> bool:
	if not can_interact(customer):
		return false
	return menu.open_offer(customer)

func purchase(expected_columns: int) -> Dictionary:
	if not can_interact(player):
		return {"ok": false, "error": "Move closer to the land sign."}
	var result: Dictionary = state.purchase(player.wallet, expected_columns)
	if result.ok:
		_reveal_column = int(result.column)
		_revealed_rows = 0
		_clearing = create_tween()
		_clearing.tween_method(_reveal_rows, 0, LandExpansionState.REGION.size.y, 0.85)
		_clearing.tween_callback(_finish_reveal)
		_state_changed()
	return result

func _reveal_rows(count: int) -> void:
	if count == _revealed_rows:
		return
	_revealed_rows = count
	grass_cover.refresh(self)
	queue_redraw()

func _finish_reveal() -> void:
	_reveal_column = -1
	_state_changed()

func _state_changed() -> void:
	grass_cover.refresh(self)
	if sign != null:
		sign.visible = not state.is_complete() and _reveal_column < 0
		sign.position = to_local(interaction_position()) - Vector2(0, 8)
	queue_redraw()

func reset_presentation() -> void:
	if _clearing != null and _clearing.is_valid():
		_clearing.kill()
	_reveal_column = -1
	_revealed_rows = 0
	_state_changed()

func _process(_delta: float) -> void:
	if prompt != null:
		prompt.visible = player.interactions == null and can_interact(player) and not player.selection.is_menu_open()

func _draw() -> void:
	if grass_cover.active:
		return
	if farming == null or farming.farmland == null:
		return
	var region: Rect2i = LandExpansionState.REGION
	var locked_width: int = region.size.x - state.unlocked_columns
	if locked_width > 0:
		_draw_cover(Rect2i(region.position, Vector2i(locked_width, region.size.y)))
	if _reveal_column >= 0 and _revealed_rows < region.size.y:
		_draw_cover(Rect2i(Vector2i(_reveal_column, region.position.y + _revealed_rows), Vector2i(1, region.size.y - _revealed_rows)))

func _draw_cover(cells: Rect2i) -> void:
	var tile_size: Vector2 = Vector2(farming.farmland.tile_set.tile_size)
	# Transparent decorations keep the existing dry FarmLand underneath visible.
	# Anchor alternation to map cells so unlocking/revealing never reshuffles weeds.
	for y: int in range(cells.position.y, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			var corner: Vector2 = farming.farmland.map_to_local(Vector2i(x, y)) - tile_size * 0.5
			var variant: int = (x + y) % WEED_REGIONS.size()
			draw_texture_rect_region(DECOR, Rect2(corner, tile_size), WEED_REGIONS[variant])

func set_grass_effect(effect: ShaderMaterial) -> void:
	if effect == null:
		grass_cover.clear()
	elif grass_cover.install(self):
		grass_cover.sync_from(effect)
	queue_redraw()

func _exit_tree() -> void:
	grass_cover.clear()
