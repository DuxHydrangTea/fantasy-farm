extends SceneTree
## Rebuild the static shadow scene after painting/moving decorative trees.
## godot --headless --path . --script res://scripts/rebuild_decorative_tree_shadows.gd

const OUTPUT: String = "res://scenes/objects/outdoor_decor/decorative_tree_shadows.tscn"
const SHADOW: Texture2D = preload("res://assets/Trees/Shadows/Variants64x80/magic_blue_shadow.png")
var _frames: Dictionary[String, Dictionary] = {}
var _images: Dictionary[Texture2D, Image] = {}

func _initialize() -> void:
	call_deferred("_build")

func _tree_texture(texture: Texture2D) -> bool:
	if texture is AtlasTexture:
		return _tree_texture((texture as AtlasTexture).atlas)
	return texture != null and texture.resource_path.begins_with("res://assets/Trees/") and not texture.resource_path.contains("/Shadows/")

func _image(texture: Texture2D) -> Image:
	if not _images.has(texture):
		_images[texture] = texture.get_image()
	return _images[texture]

func _info(texture: Texture2D, region: Rect2i) -> Dictionary:
	var key: String = str(texture.get_instance_id()) + ":" + str(region)
	if _frames.has(key):
		return _frames[key]
	var image: Image = _image(texture).get_region(region)
	var left: int = image.get_width()
	var right: int = -1
	var top: int = image.get_height()
	var bottom: int = -1
	var baked: bool = false
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.98:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)
			elif pixel.a > 0.04 and pixel.a < 0.8 and maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.02:
				baked = true
	var result: Dictionary = {"tree": bottom - top >= 20 and right - left >= 9, "baked": baked}
	if result.tree:
		var foot_left: int = image.get_width()
		var foot_right: int = -1
		for y: int in range(maxi(top, bottom - 5), bottom + 1):
			for x: int in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.98:
					foot_left = mini(foot_left, x)
					foot_right = maxi(foot_right, x)
		result["root"] = Vector2((foot_left + foot_right + 1) * 0.5, bottom + 1)
		result["width"] = right - left + 1
	_frames[key] = result
	return result

func _add_shadow(scene: Node2D, anchor: String, root_point: Vector2, canopy_width: float) -> void:
	var width: int = maxi(8, roundi(canopy_width * 36.0 / 41.0))
	var height: int = maxi(5, roundi(width * 22.0 / 36.0))
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Shadow_%03d" % scene.get_child_count()
	sprite.texture = SHADOW
	sprite.scale = Vector2(width, height) / Vector2(SHADOW.get_size())
	sprite.position = root_point + Vector2(0, -roundf(height * 3.0 / 22.0))
	sprite.set_meta("tree_anchor", anchor)
	sprite.set_meta("visible_root", root_point)
	scene.add_child(sprite)
	sprite.owner = scene

func _build() -> void:
	var world: Node = load("res://world/main_world.tscn").instantiate()
	var scene: Node2D = Node2D.new()
	scene.name = "DecorativeTreeShadows"
	# Ground cover uses z=-1. The world instance is ordered before the z=0
	# tree TileMap, so shadows shade flowers without painting over trunks.
	scene.z_index = 0
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var skipped_baked: int = 0
	for node: Node in world.find_children("*", "Sprite2D", true, false):
		var sprite: Sprite2D = node as Sprite2D
		if not sprite.visible or not _tree_texture(sprite.texture):
			continue
		var size: Vector2i = Vector2i(sprite.texture.get_size()) / Vector2i(sprite.hframes, sprite.vframes)
		var region: Rect2i = Rect2i(sprite.region_rect) if sprite.region_enabled else Rect2i(sprite.frame_coords * size, size)
		var info: Dictionary = _info(sprite.texture, region)
		if not info.tree:
			continue
		if info.baked:
			skipped_baked += 1
			continue
		var foot: Vector2 = info.root
		if sprite.flip_h:
			foot.x = region.size.x - foot.x
		if sprite.flip_v:
			foot.y = region.size.y - foot.y
		_add_shadow(scene, str(world.get_path_to(sprite)), sprite.to_global(sprite.get_rect().position + foot), float(info.width) * absf(sprite.global_scale.x))
	for node: Node in world.find_children("*", "TileMapLayer", true, false):
		var layer: TileMapLayer = node as TileMapLayer
		if not layer.visible:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var source: TileSetAtlasSource = layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null or not _tree_texture(source.texture):
				continue
			var region: Rect2i = source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
			var info: Dictionary = _info(source.texture, region)
			if not info.tree:
				continue
			if info.baked:
				skipped_baked += 1
				continue
			var data: TileData = layer.get_cell_tile_data(cell)
			# Current tree paint has no alternate transforms or texture origins.
			# Refuse a new unsupported transform instead of silently misaligning it.
			assert(layer.get_cell_alternative_tile(cell) == 0 and data.texture_origin == Vector2i.ZERO)
			var foot: Vector2 = layer.map_to_local(cell) + Vector2(info.root) - Vector2(region.size) * 0.5
			var anchor: String = str(world.get_path_to(layer)) + "@%d,%d" % [cell.x, cell.y]
			_add_shadow(scene, anchor, layer.to_global(foot), float(info.width) * absf(layer.global_scale.x))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	print("Decorative tree shadows: ", scene.get_child_count(), "; existing baked shadows left alone: ", skipped_baked)
	world.free()
	scene.free()
	quit()
