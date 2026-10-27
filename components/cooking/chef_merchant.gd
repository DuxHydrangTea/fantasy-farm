class_name ChefMerchant
extends ShopMerchant
## Uses the existing E/click, mobile and modal merchant integration.
var cooking_status: PanelContainer
var cooking_label: Label
var cooking_progress: ProgressBar
var _world: FarmWorld
var _status_elapsed: float = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	if menu is CookingMenu:
		return
	menu = preload("res://scenes/ui/cooking.tscn").instantiate() as CookingMenu
	menu.name = "CookingMenu"
	add_child(menu)

func _ready() -> void:
	super._ready()
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is FarmWorld:
			_world = ancestor as FarmWorld
			break
		ancestor = ancestor.get_parent()
	cooking_status = PanelContainer.new()
	cooking_status.name = "CookingStatus"
	cooking_status.theme = preload("res://resources/ui/game_theme.tres")
	cooking_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooking_status.scale = Vector2(0.25, 0.25)
	cooking_status.z_index = 21
	add_child(cooking_status)
	cooking_status.resized.connect(_place_cooking_status)
	var body: VBoxContainer = VBoxContainer.new()
	body.custom_minimum_size.x = 160
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooking_status.add_child(body)
	cooking_label = Label.new()
	cooking_label.clip_text = true
	cooking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooking_label.add_theme_font_size_override("font_size", 14)
	cooking_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cooking_label)
	cooking_progress = ProgressBar.new()
	cooking_progress.custom_minimum_size = Vector2(160, 8)
	cooking_progress.show_percentage = false
	cooking_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("493b2b")
	cooking_progress.add_theme_stylebox_override("background", background)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("86bc57")
	cooking_progress.add_theme_stylebox_override("fill", fill)
	body.add_child(cooking_progress)
	_place_cooking_status()
	cooking_status.hide()

func _place_cooking_status() -> void:
	var size: Vector2 = cooking_status.size * cooking_status.scale
	cooking_status.position = interaction_offset + Vector2(-size.x * 0.5, -24.0 - size.y)

func _process(delta: float) -> void:
	super._process(delta)
	_status_elapsed += delta
	if _status_elapsed >= 0.25:
		_status_elapsed = 0.0
		refresh_cooking_status()

func refresh_cooking_status() -> void:
	if _world == null or _world.tool_upgrades == null or not _world.tool_upgrades.profile_ready:
		cooking_status.hide()
		return
	var model: ChefCooking = _world.cooking
	model.advance(_world.farming.time_manager.now(), false)
	cooking_status.visible = (not model.queue.is_empty() or not model.ready.is_empty()) and not menu.is_open and not bubble.visible
	if model.queue.is_empty():
		cooking_label.text = tr("Ready: %d dishes") % model.ready.size()
		cooking_progress.value = 100.0
	else:
		var recipe: CookingRecipe = ChefCooking.find(model.queue[0].recipe)
		var progress: float = clampf(1.0 - (float(model.queue[0].finish_at) - model.updated_at) / recipe.cook_seconds, 0.0, 1.0)
		cooking_progress.value = progress * 100.0
		cooking_label.text = "%s · %d%%" % [tr(recipe.display_name), int(progress * 100.0)]
		if not model.ready.is_empty():
			cooking_label.text += "\n" + (tr("Ready: %d") % model.ready.size())
