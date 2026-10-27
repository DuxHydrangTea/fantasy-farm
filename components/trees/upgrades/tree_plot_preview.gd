class_name TreePlotPreview
extends Control
## Read-only map of the actual 17 columns × 9 rows; no planting commands.
var world: FarmWorld
var kind: TreeDefinition.Kind
var capacity: int = 9

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not is_instance_valid(world):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("d4c09c"))
	var step: float = floorf(minf((size.x - 16) / 17.0, (size.y - 16) / 9.0))
	if step < 2:
		return
	var offset: Vector2 = ((size - Vector2(17, 9) * step) * 0.5).floor()
	var origin: Vector2i = TreePlantation.region_for(kind).position + Vector2i(2, 3)
	var open_columns: int = floori(float(capacity) / 9.0)
	for column: int in range(17):
		for row: int in range(9):
			var rect: Rect2 = Rect2(offset + Vector2(column, row) * step, Vector2.ONE * (step - 2))
			var unlocked: bool = column < open_columns
			draw_rect(rect, Color("94aa70") if unlocked else Color("a9977d"))
			draw_rect(rect, Color("647747") if unlocked else Color("8a7965"), false, 1)
			var cell: Vector2i = origin + Vector2i(column * 3, row * 3)
			var tree: PerennialTree = world.trees.trees.get(cell) as PerennialTree
			if tree != null:
				draw_texture_rect(tree.definition.ready_texture, rect.grow(-1), false)
	if open_columns < 17:
		draw_rect(Rect2(offset + Vector2(open_columns * step - 1, -1), Vector2(step, step * 9)), Color("f0d491"), false, 2)
