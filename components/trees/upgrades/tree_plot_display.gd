class_name TreePlotDisplay
extends Node2D
## Ground markers use the exact staggered planting coordinates.
var plantation: TreePlantation

func _ready() -> void:
	plantation.world.tree_plot_upgrades.state.changed.connect(_changed)
	queue_redraw()

func _changed(_kind: TreeDefinition.Kind) -> void:
	queue_redraw()

func _draw() -> void:
	var levels: Dictionary = plantation.world.tree_plot_upgrades.state.capture()
	for kind: TreeDefinition.Kind in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var origin: Vector2i = TreePlantation.region_for(kind).position + Vector2i(2, 3)
		for column: int in range(17):
			for row: int in range(9):
				var cell: Vector2i = origin + Vector2i(column * 3, row * 3)
				var point: Vector2 = to_local(plantation.point_for(cell))
				var unlocked: bool = TreePlotUpgradeState.allows(levels, cell, kind)
				var color: Color = Color(0.68, 0.79, 0.42, 0.55) if unlocked else Color(0.23, 0.25, 0.20, 0.45)
				draw_rect(Rect2(point - Vector2(7, 3), Vector2(14, 6)), color, false, 1)
				if not unlocked:
					draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), color)
					draw_rect(Rect2(point - Vector2(1, 4), Vector2(2, 3)), color, false, 1)
