class_name GrassSourceCatalog
extends RefCounted
## G0 data baked from original strips; source textures are never edited.
const DATA = preload("res://resources/grass/grass_catalog_data.gd")
const ATLAS_PATH: String = "res://resources/grass/grass_poc_atlas.png"
const FRAME_SIZE: int = 16
const FRAME_COUNT: int = 8
var texture: Texture2D = load(ATLAS_PATH) as Texture2D
var types: Array[Dictionary] = []

func _init() -> void:
	types.assign(DATA.TYPES)

func size() -> int:
	return types.size()

func source(index: int) -> Dictionary:
	assert(index >= 0 and index < size(), "Unknown grass source")
	return types[index]

func local_bounds(index: int) -> Rect2:
	return Rect2(-8.0, -float(source(index).root_y), 16.0, 16.0)

func atlas_region(index: int, frame: int) -> Rect2i:
	assert(frame >= 0 and frame < FRAME_COUNT)
	return Rect2i(frame * FRAME_SIZE, index * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
