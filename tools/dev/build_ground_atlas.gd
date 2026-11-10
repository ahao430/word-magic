extends SceneTree
## One-shot: pack the 8 production ground tiles into a single 128x64
## atlas PNG (4 cols x 2 rows, no gutters) for the forest TileSet.
##
##   godot --headless --path . -s res://tools/dev/build_ground_atlas.gd
##
## Run `--import` afterwards so the atlas gets import metadata before
## build_tileset.gd loads it.

const TILE_DIR := "res://assets/tilesets/forest/ground"
const TILE_NAMES := [
	"grass_plain", "grass_dense", "grass_flowers", "dirt_plain",
	"dirt_variant", "dirt_grassy_edge", "stone_paving", "stone_moss",
]
const TILE := 32


func _init() -> void:
	var atlas := Image.create(TILE * 4, TILE * 2, false, Image.FORMAT_RGBA8)
	for i in TILE_NAMES.size():
		var tex: Texture2D = load("%s/%s.png" % [TILE_DIR, TILE_NAMES[i]])
		var img := tex.get_image()
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, Vector2i(TILE, TILE)),
				Vector2i((i % 4) * TILE, floori(i / 4.0) * TILE))
	var err := atlas.save_png("%s/forest_ground_atlas.png" % TILE_DIR)
	if err != OK:
		push_error("[atlas] save failed: %s" % err)
	else:
		print("[atlas] saved %s/forest_ground_atlas.png (128x64)" % TILE_DIR)
	quit()
