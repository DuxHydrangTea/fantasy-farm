class_name ShopMerchant
extends PhysicsBody2D
## Attaches to an existing NPC body; its sprite and collision stay scene-owned.
@export var interaction_offset: Vector2 = Vector2.ZERO
@export var catalog: ShopCatalog
@export var shop_ui: ShopUI
@export var bubble: PanelContainer
@export var bubble_text: Label
@export var prompt: Label
@export var bubble_timer: Timer
var _player: FarmPlayer

func _enter_tree() -> void:
	if shop_ui != null:
		return
	var presentation: Node2D = preload("res://scenes/ui/merchant_interaction.tscn").instantiate() as Node2D
	presentation.name = "MerchantInteraction"
	presentation.position = interaction_offset
	shop_ui = presentation.get_node("ShopUI") as ShopUI
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
	bubble_timer.timeout.connect(bubble.hide)
	bubble.resized.connect(_place_bubble)
	_place_bubble()
	for child: Node in get_children():
		if child is AnimatedSprite2D:
			(child as AnimatedSprite2D).play(&"idle_down")

func _place_bubble() -> void:
	bubble.position = Vector2(-bubble.size.x * bubble.scale.x * 0.5, -36.0 - bubble.size.y * bubble.scale.y)
	(bubble.get_node("Tail") as Polygon2D).position = Vector2(bubble.size.x * 0.5, bubble.size.y)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		# Resolve only until the local player exists, not every frame.
		var players: Array[Node] = get_tree().get_nodes_in_group(&"farm_players")
		if not players.is_empty():
			_player = players[0] as FarmPlayer
	if is_instance_valid(_player):
		prompt.visible = not _player.selection.is_menu_open() and not bubble.visible and _player.shop_interaction.nearest_merchant() == self

func open_shop(customer: FarmPlayer) -> bool:
	if customer.global_position.distance_to(interaction_position()) > 48.0 or customer.selection.is_menu_open():
		return false
	_player = customer
	bubble.hide()
	bubble_timer.stop()
	shop_ui.open(self, customer)
	return true

func thank_customer() -> void:
	bubble_text.text = "Cảm ơn bạn!\nHẹn gặp lại!"
	bubble.show()
	bubble_timer.start(3.5)
