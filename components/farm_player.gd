class_name FarmPlayer
extends CharacterBody2D
## Scene-owned references; keep gameplay in the existing components.
@export var animation: AnimationComponent
@export var state: StateComponent
@export var selection: ToolSelectionComponent
@export var camera: Camera2D
@export var farming_actions: FarmingActionComponent
@export var context_bars: ContextBarsComponent

var hive_placement: BeehivePlacementComponent
var interactions: PlayerInteractionComponent
var boosters: BoosterInteractionComponent
var wallet: WalletComponent
var shop_interaction: ShopInteraction
var item_feedback: ItemGainFeedback
var tree_interaction: TreeInteraction
var mobile_controls: MobileControls
var tool_range_ui: ToolRangeUI

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
	item_feedback = ItemGainFeedback.new()
	item_feedback.name = "ItemGainFeedback"
	item_feedback.player = self
	# Discover the scene-owned sensor once by type; editor renames stay safe.
	for child: Node in get_children():
		if child is ItemCollector:
			item_feedback.collector = child as ItemCollector
			break
	add_child(item_feedback)

	boosters = BoosterInteractionComponent.new()
	boosters.name = "BoosterInteraction"
	boosters.player = self
	state.boosters = boosters
	add_child(boosters)

	hive_placement = BeehivePlacementComponent.new()
	hive_placement.name = "HivePlacement"
	hive_placement.player = self
	state.hive_placement = hive_placement
	add_child(hive_placement)

	interactions = PlayerInteractionComponent.new()
	interactions.name = "Interactions"
	interactions.player = self
	state.interactions = interactions
	add_child(interactions)
	tree_interaction = TreeInteraction.new()
	tree_interaction.name = "TreeInteraction"
	tree_interaction.player = self
	state.tree_interaction = tree_interaction
	add_child(tree_interaction)
	mobile_controls = MobileControls.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.player = self
	add_child(mobile_controls)
