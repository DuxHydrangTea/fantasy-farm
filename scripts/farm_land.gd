@tool
class_name FarmLand
extends Node2D

@export var plot_scene: PackedScene:
	set(value):
		plot_scene = value
		_request_rebuild()
@export var rows: int = 6:
	set(value):
		rows = value
		_request_rebuild()
@export var cols: int = 6:
	set(value):
		cols = value
		_request_rebuild()
@export var gap: Vector2 = Vector2(16,16):
	set(value):
		gap = value
		_request_rebuild()

var _rebuild_pending: bool = false

func _ready() -> void:
	_request_rebuild()
	
func _request_rebuild() -> void:
	if not is_node_ready() or _rebuild_pending:
		return
		
	_rebuild_pending = true
	create_grid.call_deferred()

func create_grid() -> void:
	_rebuild_pending = false

	if not is_inside_tree():
		return
		
	for child in get_children():
		if child.has_meta(&"generated_plot"):
			remove_child(child)
			child.queue_free()
	
	if plot_scene == null:
		return

	for row in range(rows):
		for col in range(cols):
			var plot := plot_scene.instantiate() as FarmPlot
			
			if plot == null:
				push_error("Plot Scene phải có root là FarmPlot")
				return
			
			plot.plot_id = StringName("plot_%d_%d" % [col, row])
			
			plot.position = Vector2(
				col * gap.x + 8,
				row * gap.y + 16
			)
			plot.set_meta(&"generated_plot", true)	
			add_child(plot)
			
func get_plot_at_world(world_position: Vector2) -> FarmPlot:
	for child in get_children():
		if child is FarmPlot:
			var plot := child as FarmPlot
			if plot.contains_world_point(world_position):
				return plot
	return null
