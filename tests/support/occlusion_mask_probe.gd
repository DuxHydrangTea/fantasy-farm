extends SceneTree
## Render regression checks: empty space, transparent holes, foreground, grass and tiles.
var failures: Array[String] = []
var world: Node2D
var actor: Node2D
var original: AnimatedSprite2D
var overlay: AnimatedSprite2D
var wall: StaticBody2D
var wall_sprite: Sprite2D

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
	print("PASS " if value else "FAIL ", message)

func _frames() -> void:
	for index: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

func _texture(size: Vector2i, color: Color) -> ImageTexture:
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _mask_at(point: Vector2) -> float:
	var view: SubViewport = overlay.get("_mask_view") as SubViewport
	var image: Image = view.get_texture().get_image()
	var local: Vector2i = Vector2i(view.canvas_transform * point)
	return image.get_pixelv(local).a

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(128, 128)
	root.size = Vector2i(128, 128)
	world = Node2D.new()
	world.y_sort_enabled = true
	root.add_child(world)
	actor = Node2D.new()
	actor.position = Vector2(64, 64)
	world.add_child(actor)
	original = AnimatedSprite2D.new()
	original.position = Vector2(0, -12)
	original.sprite_frames = SpriteFrames.new()
	original.sprite_frames.add_frame(&"default", _texture(Vector2i(16, 24), Color(0.1, 0.4, 0.9)))
	actor.add_child(original)
	overlay = load("res://components/player_occlusion_overlay.gd").new() as AnimatedSprite2D
	overlay.source = original
	overlay.z_index = 20
	overlay.z_as_relative = false
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = load("res://shaders/player_occlusion.gdshader")
	overlay.material = shader_material
	actor.add_child(overlay)
	await _frames()
	_check(not overlay.visible, "No silhouette in empty space")

	var tint: ColorRect = ColorRect.new()
	tint.color = Color(0.0, 0.7, 0.8, 0.4)
	tint.size = Vector2(128, 128)
	tint.z_index = 50
	world.add_child(tint)
	await _frames()
	_check(not overlay.visible and _mask_at(Vector2(64, 52)) == 0.0, "UI/range tint never causes silhouette")
	tint.queue_free()

	wall = StaticBody2D.new()
	wall.position = Vector2(64, 68)
	wall_sprite = Sprite2D.new()
	wall_sprite.position = Vector2(0, -16)
	var cutout: Image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	cutout.fill(Color(0.5, 0.2, 0.1))
	for y: int in range(24):
		for x: int in range(8):
			cutout.set_pixel(x, y, Color.TRANSPARENT)
	wall_sprite.texture = ImageTexture.create_from_image(cutout)
	wall.add_child(wall_sprite)
	world.add_child(wall)
	overlay.set("_refresh_timer", 0.0)
	await _frames()
	_check(_mask_at(Vector2(68, 52)) > 0.9, "Foreground opaque pixels enter mask")
	_check(_mask_at(Vector2(60, 52)) == 0.0, "Transparent sprite padding stays clear")
	var rendered: Image = root.get_texture().get_image()
	var visible_pixel: Color = rendered.get_pixel(60, 52)
	var hidden_pixel: Color = rendered.get_pixel(68, 52)
	_check(visible_pixel.b > visible_pixel.r + 0.3, "Uncovered half retains original blue colour")
	_check(hidden_pixel.r > hidden_pixel.b + 0.2, "Covered half renders silhouette")
	rendered.save_png("/tmp/occlusion-mask-partial.png")

	wall.position.y = 60
	wall_sprite.position.y = -8
	await _frames()
	_check(not overlay.visible and _mask_at(Vector2(68, 52)) == 0.0, "Object behind player cannot trigger silhouette")
	wall.position = Vector2(100, 68)
	await _frames()
	_check(_mask_at(Vector2(68, 52)) == 0.0, "Moving away clears mask on next frame")
	wall.hide()

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = _texture(Vector2i(16, 16), Color.GREEN)
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	var grass: TileMapLayer = TileMapLayer.new()
	grass.name = "MeadowGrass"
	grass.y_sort_enabled = true
	grass.tile_set = tile_set
	grass.position = Vector2(56, 44)
	grass.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	world.add_child(grass)
	overlay.set("_refresh_timer", 0.0)
	await _frames()
	_check(not overlay.visible, "Grass tile layer is excluded")
	grass.name = "Tree"
	grass.position = Vector2(56, 60)
	atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin = Vector2i(0, 16)
	overlay.set("_refresh_timer", 0.0)
	await _frames()
	_check(_mask_at(Vector2(64, 52)) > 0.9, "Foreground Tree tile contributes actual alpha")
	root.get_texture().get_image().save_png("/tmp/occlusion-tile.png")
	var tile_render: Color = root.get_texture().get_image().get_pixel(64, 52)
	_check(tile_render.r > 0.45 and tile_render.g > 0.7, "Tile mask aligns with rendered tile texture origin")
	var half_tile: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	half_tile.fill(Color.GREEN)
	for y: int in range(16):
		for x: int in range(8):
			half_tile.set_pixel(x, y, Color.TRANSPARENT)
	atlas.texture = ImageTexture.create_from_image(half_tile)
	grass.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO, TileSetAtlasSource.TRANSFORM_FLIP_H)
	await _frames()
	_check(_mask_at(Vector2(60, 52)) > 0.9 and _mask_at(Vector2(68, 52)) == 0.0, "Flipped tree tile alpha matches cell transform")
	grass.hide()
	await _frames()
	_check(not overlay.visible, "Hidden tile layer clears silhouette")
	print("OCCLUSION RESULT: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
