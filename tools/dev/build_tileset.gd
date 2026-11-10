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
	# 4 cols x 6 rows: 8 base tiles + 16 transition tiles (rows 2-5).
	for i in 24:
		source.create_tile(Vector2i(i % 4, floori(i / 4.0)))
	tileset.add_source(source, 0)

	var err := ResourceSaver.save(tileset, TILESET_PATH)
	if err != OK:
		push_error("[tileset] save failed: %s" % err)
	else:
		print("[tileset] saved " + TILESET_PATH)
	quit()
