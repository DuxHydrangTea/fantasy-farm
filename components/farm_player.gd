class_name FarmPlayer
extends CharacterBody2D
## Scene-owned references; keep gameplay in the existing components.
@export var animation: AnimationComponent
@export var state: StateComponent
@export var selection: ToolSelectionComponent
@export var camera: Camera2D
@export var farming_actions: FarmingActionComponent
@export var context_bars: ContextBarsComponent

var wallet: WalletComponent
var shop_interaction: ShopInteraction
var item_feedback: ItemGainFeedback

func _enter_tree() -> void:
	add_to_group(&"farm_players")
	if is_instance_valid(wallet):
		return
	wallet = WalletComponent.new()
	wallet.name = "Wallet"
	add_child(wallet)
	shop_interaction = ShopInteraction.new()
	shop_interaction.name = "ShopInteraction"
	shop_interaction.player = self
	state.shop_interaction = shop_interaction
	add_child(shop_interaction)
	var hud: CanvasLayer = preload("res://components/wallet_hud.gd").new()
	hud.name = "WalletHUD"
	hud.wallet = wallet
	add_child(hud)
	item_feedback = ItemGainFeedback.new()
	item_feedback.name = "ItemGainFeedback"
	item_feedback.player = self
	# Discover the scene-owned sensor once by type; editor renames stay safe.
	for child: Node in get_children():
		if child is ItemCollector:
			item_feedback.collector = child as ItemCollector
			break
	add_child(item_feedback)
