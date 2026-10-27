extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for path: String in ["res://output/flower_scene_refactor_backup/scenes/flowers/flower_pot.tscn", "res://scenes/flowers/flower_pot.tscn"]:
		var node: Variant = load(path).instantiate()
		root.add_child(node)
		await process_frame
		var bar: ProgressBar = node.get_node("Progress/Bar") as ProgressBar
		print(path, " size=",bar.size," min=",bar.get_combined_minimum_size())
		bar.add_theme_font_size_override("font_size", 1)
		await process_frame
		bar.size = Vector2(11,2)
		print("Small font size=",bar.size," min=",bar.get_combined_minimum_size())
		node.free()
	quit()
