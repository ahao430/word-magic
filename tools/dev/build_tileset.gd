extends SceneTree
## One-shot: build the forest ground TileSet resource from the packed
## atlas. Ground tiles intentionally get NO collision (props and cliffs
## carry collision instead, per IMPORT_GUIDE).
##
##   godot --headless --path . -s res://tools/dev/build_tileset.gd
##
## Requires forest_ground_atlas.png to be imported already.

const ATLAS_PATH := "res://assets/tilesets/forest/ground/forest_ground_atlas.png"
const TILESET_PATH := "res://assets/tilesets/forest/forest_ground.tres"


func _init() -> void:
	var texture: Texture2D = load(ATLAS_PATH)
	if texture == null:
		push_error("[tileset] atlas not found: " + ATLAS_PATH)
		quit(1)
		return

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.resource_name = "ForestGround"

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(32, 32)
	# 4 cols x 11 rows: base + grass-dirt transitions + water family.
	for i in 44:
		source.create_tile(Vector2i(i % 4, floori(i / 4.0)))

	# Attach the source BEFORE touching physics so every TileData sees
	# the new layer (standalone TileData keeps a zero-size physics array).
	tileset.add_source(source, 0)

	# Water-family tiles (atlas indices 24..43 = rows 6..10) block
	# movement with a full-tile collision rectangle.
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	for i in range(24, 44):
		var coords := Vector2i(i % 4, floori(i / 4.0))
		var data: TileData = source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		# Polygon points are relative to the TILE CENTER, so a full-tile
		# rectangle is -16..+16, not 0..32 (centering bug shifted every
		# water shape half a tile to the south-east).
		data.set_collision_polygon_points(0, data.get_collision_polygons_count(0) - 1,
				PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))

	var err := ResourceSaver.save(tileset, TILESET_PATH)
	if err != OK:
		push_error("[tileset] save failed: %s" % err)
	else:
		print("[tileset] saved " + TILESET_PATH)
	quit()
