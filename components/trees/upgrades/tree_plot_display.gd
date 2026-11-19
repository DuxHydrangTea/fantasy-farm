class_name TreePlotDisplay
extends Node2D
## Vẽ dấu ô khu cây trên đất theo đúng tọa độ trồng so le.
## Màu và biểu tượng thể hiện ô đã mở hoặc còn khóa.

## Plantation cung cấp tọa độ và trạng thái nâng cấp.
var plantation: TreePlantation
## Ô trống đang được nhắm tới để hiển thị viền chọn.
var focused_cell: Vector2i = Vector2i(-1, -1)
## Loại khu cây của ô đang được nhắm tới.
var focused_kind: int = -1

func _ready() -> void:
	plantation.world.tree_plot_upgrades.state.changed.connect(_changed)
	queue_redraw()

## Cập nhật ô trống đang được chọn nổi bật và chỉ vẽ lại khi thay đổi.
func set_focused_plot(cell: Vector2i, kind: int) -> void:
	if focused_cell == cell and focused_kind == kind:
		return
	focused_cell = cell
	focused_kind = kind
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
				if kind == focused_kind and cell == focused_cell and not plantation.trees.has(cell):
					draw_rect(Rect2(point - Vector2(9, 5), Vector2(18, 10)), Color(0.98, 0.87, 0.45, 0.95), false, 2)
