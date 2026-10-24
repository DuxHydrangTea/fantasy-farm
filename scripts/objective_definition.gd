class_name ObjectiveDefinition
extends Resource
## Stable authored objective. Descriptions are localization source strings.
@export var objective_id: StringName
@export var title: String
@export var description: String
@export var condition: StringName
@export var required: int = 1
@export var reward_coins: int = 25
@export var state_condition: bool = false
