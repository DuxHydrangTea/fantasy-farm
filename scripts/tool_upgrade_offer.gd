class_name ToolUpgradeOffer
extends Resource
@export var tool: StringName
@export_range(2, 6) var target_level: int = 2
@export_range(1, 1000000000) var price: int = 30000
@export_range(0, 47) var required_purchased_columns: int = 1

@export_range(0, 30) var wood_cost: int = 0
