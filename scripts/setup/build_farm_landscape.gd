extends SceneTree
## Rebuild the hand-authored landscape scene. Does not modify gameplay or save data.
const OUTPUT: String = "res://world/farm_landscape.tscn"
var landscape: Node2D
var source_world: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var grasses: TileMapLayer
var flowers: TileMapLayer
var water: TileMapLayer
var stones: TileMapLayer
var objects: Node2D
var static_tiles: TileSet = preload("res://tilesets/static_decor_tileset.tres")
var serial: int = 0

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	rng.seed = 22102026
	source_world = load("res://world/main_world.tscn").instantiate() as Node2D
	landscape = Node2D.new()
	landscape.name = "FarmLandscape"
	landscape.y_sort_enabled = true
	landscape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	landscape.set_meta("design", "Woodland edges, working farm corners and open planting gardens")
	_meadow_floor()
	grasses = _layer("MeadowGrass", "res://tilesets/my_decor_grass_tileset.tres", -1)
	flowers = _layer("Wildflowers", "res://tilesets/my_decor_not_potted_flower_tileset.tres", -1)
	water = _layer("PondPlants", "res://tilesets/my_decor_water_tileset.tres", 0)
	stones = _layer("EdgeStones", "res://tilesets/my_decor_rock_tileset.tres", -1)
	objects = Node2D.new()
	objects.name = "Landmarks"
	objects.y_sort_enabled = true
	_attach(objects, landscape)
	_woodland()
	_farm_corners()
	_pond()
	_garden_edges()
	_details()
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(landscape) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	print("LANDSCAPE_BUILT ", JSON.stringify({"nodes": serial, "grass": grasses.get_used_cells().size(), "flowers": flowers.get_used_cells().size(), "water": water.get_used_cells().size(), "rocks": stones.get_used_cells().size()}))
	source_world.free()
	landscape.free()
	quit()

func _attach(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = landscape

func _layer(label: String, path: String, depth: int) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = label
	layer.tile_set = load(path) as TileSet
	layer.z_index = depth
	layer.collision_enabled = false
	_attach(layer, landscape)
	return layer

func _meadow_floor() -> void:
	# Subtle ground-only variation remains underneath every future planted tree.
	var ground: TileMapLayer = source_world.get_node("Ground") as TileMapLayer
	for variant: int in range(2):
		var layer: TileMapLayer = TileMapLayer.new()
		layer.name = "MeadowShade" if variant == 0 else "MeadowSun"
		layer.tile_set = ground.tile_set
		layer.z_index = -3
		layer.collision_enabled = false
		layer.modulate = Color(0.96, 0.965, 0.96) if variant == 0 else Color(1.03, 1.035, 1.01)
		_attach(layer, landscape)
		for y: int in range(0, 104):
			for x: int in range(1, 153):
				var exterior: bool = (y < 12 or y > 92 or x > 122 or x < 4)
				var garden: bool = y >= 59 and y <= 87 and ((x >= 11 and x <= 62) or (x >= 67 and x <= 117))
				if not exterior and not garden:
					continue
				var value: float = sin(x * 0.14 + sin(y * 0.17)) + cos(y * 0.21 + sin(x * 0.11)) * 0.7
				if (variant == 0 and value > 0.8) or (variant == 1 and value < -0.9):
					var cell: Vector2i = Vector2i(x, y)
					layer.set_cell(cell, ground.get_cell_source_id(cell), ground.get_cell_atlas_coords(cell))

func _instance(path: String, point: Vector2, label: String) -> Node2D:
	var object: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	serial += 1
	object.name = "%s_%03d" % [label, serial]
	object.position = point
	_attach(object, objects)
	return object

func _tree(point: Vector2, species: String = "oak", small: bool = false) -> void:
	_instance("res://scenes/trees/%s_%s_tree.tscn" % ["medium" if small else "big", species], point, "Woodland" + species.capitalize())
	_tufts(point + Vector2(0, 12), 37, 19, 6)

func _tufts(center: Vector2, rx: float, ry: float, count: int, floral: bool = false) -> void:
	for index: int in range(count):
		var angle: float = rng.randf_range(0, TAU)
		var distance: float = sqrt(rng.randf())
		var point: Vector2 = center + Vector2(cos(angle) * rx, sin(angle) * ry) * distance
		var layer: TileMapLayer = flowers if floral else grasses
		var source_id: int = rng.randi_range(0, layer.tile_set.get_source_count() - 1) if floral else [7, 8, 9, 2, 3, 4][rng.randi_range(0, 5)]
		var atlas: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
		layer.set_cell(layer.local_to_map(point), source_id, atlas.get_tile_id(0))

func _prop(source_id: int, coords: Vector2i, point: Vector2, label: String, solid: bool = true) -> void:
	var source: TileSetAtlasSource = static_tiles.get_source(source_id) as TileSetAtlasSource
	assert(source.has_tile(coords), "Missing decor tile: " + label)
	var rect: Rect2i = source.get_tile_texture_region(coords)
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = source.texture
	texture.region = Rect2(rect)
	texture.filter_clip = true
	_sprite(texture, point, label, solid)

func _sprite(texture: Texture2D, point: Vector2, label: String, solid: bool = true) -> Node2D:
	serial += 1
	var object: Node2D = StaticBody2D.new() if solid else Node2D.new()
	object.name = "%s_%03d" % [label, serial]
	object.position = point
	_attach(object, objects)
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	visual.texture = texture
	visual.position.y = -texture.get_height() * 0.5 + 3.0
	_attach(visual, object)
	if solid:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(maxf(6, texture.get_width() * 0.65), 7)
		var collider: CollisionShape2D = CollisionShape2D.new()
		collider.name = "Footprint"
		collider.position.y = -1.5
		collider.shape = shape
		_attach(collider, object)
	return object

func _crop_sprite(path: String, region: Rect2, point: Vector2, label: String, solid: bool = true) -> Node2D:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = load(path) as Texture2D
	texture.region = region
	texture.filter_clip = true
	return _sprite(texture, point, label, solid)

func _woodland() -> void:
	# Broken clusters frame the farm, with breathing room around roads and the shop.
	var centers: Array[Vector2] = [Vector2(144, 120), Vector2(340, 128), Vector2(620, 116), Vector2(880, 128), Vector2(1112, 116), Vector2(1450, 112), Vector2(1955, 140), Vector2(2008, 350), Vector2(2032, 600), Vector2(2040, 850), Vector2(2035, 1120), Vector2(2020, 1400), Vector2(1832, 1545), Vector2(1570, 1550), Vector2(1265, 1540), Vector2(965, 1555), Vector2(660, 1540), Vector2(360, 1550), Vector2(115, 1515), Vector2(48, 1250), Vector2(43, 1010), Vector2(40, 780), Vector2(36, 520), Vector2(34, 300)]
	for index: int in range(centers.size()):
		var center: Vector2 = centers[index]
		var offsets: Array[Vector2] = [Vector2(-26, -9), Vector2(28, 7), Vector2(4, -43)]
		for extra: int in range(rng.randi_range(0, 3)):
			offsets.append(Vector2(rng.randf_range(-48, 48), rng.randf_range(-48, 20)))
		for j: int in range(offsets.size()):
			var point: Vector2 = center + offsets[j]
			point.x = maxf(20, point.x)
			_tree(point, "birch" if rng.randf() < 0.25 else "oak")
		if index % 2 == 0:
			_tree(center + Vector2(55, 30), "birch", true)
		_tufts(center + Vector2(10, 24), 85, 38, 25)
		_tufts(center + Vector2(42, 28), 32, 15, 5, true)
	# More distant trees break up the wide eastern meadow without a straight wall.
	for point: Vector2 in [Vector2(2210, 260), Vector2(2300, 320), Vector2(2170, 510), Vector2(2250, 770), Vector2(2195, 1000), Vector2(2310, 1255), Vector2(2150, 1520)]:
		_tree(point, "oak")
		_tree(point + Vector2(42, 29), "birch")

func _farm_corners() -> void:
	# The top service strip lies outside all 1,632 farm plots and the unlock signs.
	_prop(5, Vector2i.ZERO, Vector2(566, 259), "FarmWell")
	_prop(0, Vector2i.ZERO, Vector2(603, 258), "WaterBarrel")
	_prop(1, Vector2i(1, 0), Vector2(635, 260), "StackedHay")
	_instance("res://scenes/objects/outdoor_decor/crate.tscn", Vector2(655, 258), "SeedCrate")
	_crop_sprite("res://assets/Outdoor decoration/Scarecrows.png", Rect2(0, 0, 32, 32), Vector2(832, 258), "Scarecrow")
	for x: int in [160, 224, 304, 712, 760, 880]:
		_tufts(Vector2(x, 255), 24, 8, 4, true)
	# Coop: supplies are against the east wall, away from the feed stations.
	_prop(1, Vector2i.ZERO, Vector2(1380, 376), "CoopHay")
	_prop(1, Vector2i(1, 0), Vector2(1376, 397), "CoopHay")
	_prop(2, Vector2i.ZERO, Vector2(1358, 423), "CoopNest", false)
	_prop(2, Vector2i(1, 0), Vector2(1381, 438), "CoopNest", false)
	_prop(0, Vector2i.ZERO, Vector2(1380, 345), "CoopBarrel")
	_tufts(Vector2(1026, 539), 16, 8, 5)
	_tufts(Vector2(1366, 534), 23, 11, 7)
	# Barn: a compact stack by the house, not in the herd's main circulation.
	_prop(1, Vector2i(1, 0), Vector2(1268, 622), "BarnHay")
	_prop(1, Vector2i.ZERO, Vector2(1295, 631), "BarnHay")
	_instance("res://scenes/objects/outdoor_decor/crate.tscn", Vector2(1270, 646), "BarnCrate")
	_tufts(Vector2(1368, 839), 20, 17, 7)
	_tufts(Vector2(1034, 845), 20, 13, 6)
	# Flower garden front corners. Preserve all pots and seed dispensers.
	_pot(Vector2(1443, 554), 0)
	_pot(Vector2(1795, 554), 3)
	# Shop frontage and a shaded stopping place west of the house.
	_tree(Vector2(1600, 187), "birch")
	_prop(6, Vector2i(2, 0), Vector2(1638, 201), "MarketBench")
	_prop(0, Vector2i(1, 0), Vector2(1825, 200), "MarketBarrel")
	_instance("res://scenes/objects/outdoor_decor/crate.tscn", Vector2(1848, 200), "DeliveryCrate")
	_pot(Vector2(1659, 201), 1)
	_tufts(Vector2(1585, 190), 31, 12, 6, true)

func _pot(point: Vector2, source_index: int) -> void:
	var tiles: TileSet = load("res://tilesets/my_decor_potted_flower_tileset.tres") as TileSet
	_animated_tile(tiles, source_index, point, "FlowerPot", true)

func _animated_tile(tiles: TileSet, source_index: int, point: Vector2, label: String, solid: bool = false) -> void:
	var source: TileSetAtlasSource = tiles.get_source(source_index) as TileSetAtlasSource
	var coords: Vector2i = source.get_tile_id(0)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_speed(&"default", 6.0)
	var count: int = source.get_tile_animation_frames_count(coords)
	for frame: int in range(count):
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = source.texture
		texture.region = Rect2(source.get_tile_texture_region(coords, frame))
		texture.filter_clip = true
		frames.add_frame(&"default", texture)
	var object: Node2D = _sprite(frames.get_frame_texture(&"default", 0), point, label, solid)
	var old_visual: Sprite2D = object.get_node("Visual") as Sprite2D
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedVisual"
	sprite.position = old_visual.position
	sprite.sprite_frames = frames
	sprite.autoplay = "default"
	sprite.frame = rng.randi_range(0, count - 1)
	object.remove_child(old_visual)
	old_visual.free()
	_attach(sprite, object)

func _pond() -> void:
	# Lily pads and stones hug three banks, leaving a wide swimming channel.
	var patches: Array[Vector2] = [Vector2(1472, 803), Vector2(1500, 823), Vector2(1776, 710), Vector2(1758, 738), Vector2(1744, 840)]
	var source_ids: Array[int] = []
	for index: int in range(water.tile_set.get_source_count()):
		var id: int = water.tile_set.get_source_id(index)
		var source: TileSetAtlasSource = water.tile_set.get_source(id) as TileSetAtlasSource
		if "Lillypad_Green" in source.texture.resource_path or "Lillypad_Purple" in source.texture.resource_path:
			source_ids.append(id)
	for patch: Vector2 in patches:
		for index: int in range(4):
			var point: Vector2 = patch + Vector2(rng.randf_range(-18, 18), rng.randf_range(-12, 12))
			var source_id: int = source_ids[rng.randi_range(0, source_ids.size() - 1)]
			water.set_cell(water.local_to_map(point), source_id, Vector2i.ZERO)
	for point: Vector2 in [Vector2(1464, 737), Vector2(1494, 731), Vector2(1624, 707), Vector2(1688, 684)]:
		_tufts(point, 18, 10, 5)
	_prop(0, Vector2i.ZERO, Vector2(1616, 640), "FishingBarrel")
	_instance("res://scenes/objects/outdoor_decor/crate.tscn", Vector2(1594, 644), "FishingCrate")
	# Small wooden landing on the grass bank; it never changes swimming boundaries.
	_prop(6, Vector2i(2, 0), Vector2(1548, 699), "PondBench")
	_ambient(Vector2(1487, 730), "frog_01", "idle_right", Vector2(0, 0), 0.0)

func _garden_edges() -> void:
	# Fruit / timber grids start at y=984. The narrow entrance strips end at y=968.
	_prop(6, Vector2i(2, 0), Vector2(310, 956), "OrchardBench")
	_prop(0, Vector2i.ZERO, Vector2(350, 956), "OrchardBarrel")
	_pot(Vector2(280, 957), 2)
	_instance("res://scenes/objects/outdoor_decor/written_wooden_sign.tscn", Vector2(939, 955), "OrchardSign")
	_instance("res://scenes/objects/outdoor_decor/written_wooden_sign.tscn", Vector2(1126, 955), "TimberSign")
	_prop(6, Vector2i.ZERO, Vector2(1725, 956), "WoodlandBench")
	_prop(1, Vector2i(1, 0), Vector2(1790, 956), "GardenHay")
	_pot(Vector2(1687, 957), 0)
	# Low borders only, keeping every legal planting position and canopy space open.
	for x: int in range(190, 955, 80):
		if x > 380 and x < 860:
			_tufts(Vector2(x, 946), 19, 7, 3, true)
	for x: int in range(1190, 1640, 85):
		_tufts(Vector2(x, 945), 21, 7, 4)
	for y: int in range(1030, 1370, 75):
		_tufts(Vector2(168, y), 6, 23, 4, true)
		_tufts(Vector2(1878, y), 6, 22, 4)
	# Small meadow tufts between planting rows; purely visual and below trees.
	for region: Rect2i in [Rect2i(12, 61, 49, 25), Rect2i(68, 61, 49, 25)]:
		for y: int in range(region.position.y + 1, region.end.y, 3):
			for x: int in range(region.position.x, region.end.x):
				if rng.randf() < 0.12:
					grasses.set_cell(Vector2i(x, y), 7 + rng.randi_range(0, 2), Vector2i.ZERO)
	# A southern picnic clearing beyond the existing bottom path.
	_tree(Vector2(1100, 1512), "oak")
	_prop(6, Vector2i(2, 0), Vector2(1145, 1518), "PicnicBench")
	_pot(Vector2(1174, 1520), 4)
	_tufts(Vector2(1124, 1544), 58, 19, 12, true)

func _ambient(point: Vector2, species: String, animation: String, radius: Vector2, speed: float, flower_stops: PackedVector2Array = PackedVector2Array()) -> void:
	var frames_path: String = "res://sprite_frames/animals/%s_frames.tres" % species
	var frames: SpriteFrames = load(frames_path) as SpriteFrames
	if not frames.has_animation(animation):
		animation = str(frames.get_animation_names()[0])
	serial += 1
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "Ambient_%s_%03d" % [species, serial]
	sprite.sprite_frames = frames
	sprite.animation = StringName(animation)
	sprite.autoplay = animation
	sprite.position = point
	sprite.set_script(load("res://components/landscape/ambient_flutter.gd"))
	sprite.set("radius", radius)
	sprite.set("speed", speed)
	sprite.set("phase", rng.randf_range(0, TAU))
	sprite.set("flower_stops", flower_stops)
	_attach(sprite, objects)

func _details() -> void:
	# Color accents follow the outside of fences, with deliberate breaks at gates.
	for x: int in range(152, 912, 64):
		_tufts(Vector2(x, 883), 20, 5, 4, x % 3 == 0)
	for y: int in range(320, 865, 62):
		_tufts(Vector2(105, y), 7, 18, 4)
		_tufts(Vector2(948, y), 5, 16, 3)
	for x: int in [1060, 1110, 1300, 1350, 1480, 1540, 1720, 1780]:
		_tufts(Vector2(x, 884), 20, 5, 4, true)
	for point: Vector2 in [Vector2(300, 154), Vector2(732, 165), Vector2(1993, 460), Vector2(1994, 990), Vector2(454, 1510), Vector2(1434, 1500)]:
		var source_id: int = stones.tile_set.get_source_id(rng.randi_range(0, stones.tile_set.get_source_count() - 1))
		var source: TileSetAtlasSource = stones.tile_set.get_source(source_id) as TileSetAtlasSource
		stones.set_cell(stones.local_to_map(point), source_id, source.get_tile_id(0))
	var swarm: Node2D = (load("res://world/butterfly_swarm.tscn") as PackedScene).instantiate() as Node2D
	swarm.name = "ButterflySwarm"
	_attach(swarm, landscape)
