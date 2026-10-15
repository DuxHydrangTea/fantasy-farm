@tool
extends EditorScript


const TILESET_PATHS := [
	"res://world/buildings/tilesets/houses/buildings_house_1_tiles.tres",
	"res://world/buildings/tilesets/houses/buildings_house_2_tiles.tres",
	"res://world/buildings/tilesets/houses/buildings_house_3_tiles.tres",
	"res://world/buildings/tilesets/houses/buildings_house_4_tiles.tres",
	"res://world/buildings/tilesets/houses/buildings_house_5_tiles.tres",
	# unique buildings
	"res://world/buildings/tilesets/unique/barn_building_tiles.tres",
	"res://world/buildings/tilesets/unique/blacksmith_house_building_tiles.tres",
	"res://world/buildings/tilesets/unique/church_building_tiles.tres",
	"res://world/buildings/tilesets/unique/coop_building_tiles.tres",
	"res://world/buildings/tilesets/unique/fisherman_house_building_tiles.tres",
	"res://world/buildings/tilesets/unique/green_house_building_tiles.tres",
	"res://world/buildings/tilesets/unique/inn_building_tiles.tres",
	"res://world/buildings/tilesets/unique/shed_building_tiles.tres",
	"res://world/buildings/tilesets/unique/silo_building_tiles.tres",
	"res://world/buildings/tilesets/unique/stalls_building_tiles.tres",
	"res://world/buildings/tilesets/unique/windmill_building_tiles.tres",
]

const MERGED_TILESET_PATH := "res://world/buildings/tilesets/buildings_all_tiles.tres"

const TEMPLATE_SOURCE_ID := 0


func _run() -> void:
	# 1. Setup metadata cho từng TileSet riêng.
	for tile_path in TILESET_PATHS:
		_handle(tile_path)

	# 2. Merge tất cả vào TileSet tổng.
	_merge_tilesets()


func _handle(tile_path: String) -> void:
	print("Handling resource: ", tile_path)

	var tile_set := load(tile_path) as TileSet

	if tile_set == null:
		push_error("Cannot load TileSet: " + tile_path)
		return

	var template_source := tile_set.get_source(
		TEMPLATE_SOURCE_ID
	) as TileSetAtlasSource

	if template_source == null:
		push_error(
			"Template source %s not found in %s"
			% [TEMPLATE_SOURCE_ID, tile_path]
		)
		return

	for i in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(i)

		if source_id == TEMPLATE_SOURCE_ID:
			continue

		var target_source := tile_set.get_source(
			source_id
		) as TileSetAtlasSource

		if target_source == null:
			continue

		copy_source_metadata(
			tile_set,
			template_source,
			target_source
		)

		print(
			"Copied metadata to source: ",
			source_id
		)

	ResourceSaver.save(
		tile_set,
		tile_path
	)

	print("Done: ", tile_path)


func copy_source_metadata(
	tile_set: TileSet,
	template: TileSetAtlasSource,
	target: TileSetAtlasSource
) -> void:

	var tiles_to_remove: Array[Vector2i] = []

	for i in target.get_tiles_count():
		tiles_to_remove.append(
			target.get_tile_id(i)
		)

	for coords in tiles_to_remove:
		target.remove_tile(coords)


	# Tạo lại tile giống hệt source master.
	for i in template.get_tiles_count():
		var coords := template.get_tile_id(i)
		var master_size := template.get_tile_size_in_atlas(
			coords
		)

		target.create_tile(
			coords,
			master_size
		)

		var from := template.get_tile_data(
			coords,
			0
		)

		var to := target.get_tile_data(
			coords,
			0
		)

		if from == null or to == null:
			continue

		# Y Sort
		to.y_sort_origin = from.y_sort_origin

		# Physics
		for layer in tile_set.get_physics_layers_count():
			var polygon_count := (
				from.get_collision_polygons_count(layer)
			)

			to.set_collision_polygons_count(
				layer,
				polygon_count
			)

			for polygon_index in polygon_count:
				to.set_collision_polygon_points(
					layer,
					polygon_index,
					from.get_collision_polygon_points(
						layer,
						polygon_index
					)
				)


func _merge_tilesets() -> void:
	print("Merging TileSets...")

	var merged := TileSet.new()

	var next_source_id := 0

	for tile_path in TILESET_PATHS:
		var source_tile_set := load(
			tile_path
		) as TileSet

		if source_tile_set == null:
			push_error(
				"Cannot load TileSet: " + tile_path
			)
			continue

		# Copy config TileSet từ TileSet đầu tiên.
		if next_source_id == 0:
			_copy_tileset_settings(
				source_tile_set,
				merged
			)

		for i in source_tile_set.get_source_count():
			var old_source_id := source_tile_set.get_source_id(i)

			var source := source_tile_set.get_source(
				old_source_id
			)

			if source == null:
				continue

			# duplicate(true) để tránh merged TileSet
			# dùng chung resource instance với TileSet gốc.
			var duplicated_source := source.duplicate(true)

			merged.add_source(
				duplicated_source,
				next_source_id
			)

			print(
				"Added source ",
				old_source_id,
				" from ",
				tile_path,
				" -> merged source ",
				next_source_id
			)

			next_source_id += 1

	var error := ResourceSaver.save(
		merged,
		MERGED_TILESET_PATH
	)

	if error != OK:
		push_error(
			"Failed to save merged TileSet. Error: %s"
			% error
		)
		return

	print(
		"Merge complete: ",
		MERGED_TILESET_PATH
	)


func _copy_tileset_settings(
	source: TileSet,
	target: TileSet
) -> void:

	target.tile_size = source.tile_size

	# Physics layers
	for layer in source.get_physics_layers_count():
		target.add_physics_layer()

		target.set_physics_layer_collision_layer(
			layer,
			source.get_physics_layer_collision_layer(
				layer
			)
		)

		target.set_physics_layer_collision_mask(
			layer,
			source.get_physics_layer_collision_mask(
				layer
			)
		)

		target.set_physics_layer_physics_material(
			layer,
			source.get_physics_layer_physics_material(
				layer
			)
		)

	# Navigation layers
	for layer in source.get_navigation_layers_count():
		target.add_navigation_layer()

		target.set_navigation_layer_layers(
			layer,
			source.get_navigation_layer_layers(
				layer
			)
		)
