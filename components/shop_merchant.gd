class_name ShopMerchant
extends PhysicsBody2D
## Attaches to an existing NPC body; its sprite and collision stay scene-owned.
@export var interaction_offset: Vector2 = Vector2.ZERO
@export var interaction_label: String = ""
@export var catalog: ShopCatalog
@export var shop_ui: ShopUI
@export var menu: TradeMenu
@export var bubble: PanelContainer
@export var bubble_text: Label
@export var prompt: Label
@export var bubble_timer: Timer
## Specialized merchant panels can reuse prompts without retaining an unused shop.
var create_shop_ui: bool = true
var _player: FarmPlayer

func _enter_tree() -> void:
	if menu != null:
		return
	if shop_ui != null:
		menu = shop_ui
		return
	var presentation: Node2D = preload("res://scenes/ui/merchant_interaction.tscn").instantiate() as Node2D
	presentation.name = "MerchantInteraction"
	presentation.position = interaction_offset
	shop_ui = presentation.get_node("ShopUI") as ShopUI
	if create_shop_ui:
		menu = shop_ui
	else:
		shop_ui.free()
		shop_ui = null
	bubble = presentation.get_node("Bubble") as PanelContainer
	bubble_text = bubble.get_node("Text") as Label
	prompt = presentation.get_node("Prompt") as Label
	bubble_timer = presentation.get_node("BubbleTimer") as Timer
	if catalog == null:
		catalog = preload("res://resources/shops/farm_supply.tres")
	add_child(presentation)

func interaction_position() -> Vector2:
	return to_global(interaction_offset)

func _ready() -> void:
	add_to_group(&"shop_merchants")
	bubble.hide()
	prompt.hide()
	_refresh_prompt()
	bubble_timer.timeout.connect(bubble.hide)
	bubble.resized.connect(_place_bubble)
	_place_bubble()
	for child: Node in get_children():
		if child is AnimatedSprite2D:
			(child as AnimatedSprite2D).play(&"idle_down")

func _place_bubble() -> void:
	# The mirrored atlas keeps its tail in the fixed left/bottom borders.
	# Anchor its tip to the NPC body, including presentations offset for interaction.
	var anchor: Vector2 = (bubble.get_parent() as Node2D).to_local(global_position)
	bubble.position = anchor + Vector2(-5.5 * bubble.scale.x, -36.0 - bubble.size.y * bubble.scale.y)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		# Resolve only until the local player exists, not every frame.
		var players: Array[Node] = get_tree().get_nodes_in_group(&"farm_players")
		if not players.is_empty():
			_player = players[0] as FarmPlayer
	if is_instance_valid(_player):
		prompt.visible = _player.interactions == null and not _player.selection.is_menu_open() and not bubble.visible and _player.shop_interaction.nearest_merchant() == self
		if prompt.visible:
			_refresh_prompt()

func open_shop(customer: FarmPlayer) -> bool:
	if not is_within_interaction_range(customer) or customer.selection.is_menu_open():
		return false
	_player = customer
	bubble.hide()
	bubble_timer.stop()
	return menu.open(self, customer)

func is_within_interaction_range(customer: FarmPlayer) -> bool:
	return customer.global_position.distance_to(interaction_position()) <= 48.0

func thank_customer() -> void:
	bubble_text.text = tr("Thank you!\nSee you again!")
	bubble.show()
	bubble_timer.start(3.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		bubble_text.text = tr("Thank you!\nSee you again!")
		_refresh_prompt()

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt):
		return
	var action: StringName = _player.state.action_harvest if is_instance_valid(_player) and is_instance_valid(_player.state) else &"harvest"
	prompt.text = "[%s] %s" % [GameText.action_key(action), interaction_action_text()]

func interaction_sprite() -> Node2D:
	for child: Node in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
	return null

func interaction_action_text() -> String:
	if not interaction_label.is_empty():
		return tr(interaction_label)
	if menu is CookingMenu:
		return tr("Kitchen")
	if menu is ShopUI and catalog != null and catalog.display_name != "LAI BUON'S SHOP":
		return tr(catalog.display_name)
	return tr("Sell produce") if menu is ProduceSalesUI else tr("Trade")
