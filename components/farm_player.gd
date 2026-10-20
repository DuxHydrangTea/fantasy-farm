class_name FarmPlayer
extends CharacterBody2D
## Scene-owned references; keep gameplay in the existing components.
@export var animation: AnimationComponent
@export var state: StateComponent
@export var selection: ToolSelectionComponent
@export var camera: Camera2D
@export var farming_actions: FarmingActionComponent
@export var context_bars: ContextBarsComponent
