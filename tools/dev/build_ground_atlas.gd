extends SceneTree
## One-shot: pack the atlas for the forest ground TileSet.
##
##   godot --headless --path . -s res://tools/dev/build_ground_atlas.gd
##
## Layout: 4 columns x 11 rows of 32px tiles (128 x 352).
##   rows 0-1: the 8 base ground tiles (grass/dirt/stone variants)
##   rows 2-5: 16 grass->dirt transitions (index == side bitmask,
##             N=1, E=2, S=4, W=8; row = 2 + mask/4)
##   row 6:    4 water surface variants
##   rows 7-10: 16 land->water shore transitions (same bitmask order)
##
## Run `--import` afterwards so the atlas gets import metadata before
## build_tileset.gd loads it.

const TILE_DIR := "res://assets/tilesets/forest/ground"
const BASE_TILE_NAMES := [
	"grass_plain", "grass_dense", "grass_flowers", "dirt_plain",
	"dirt_variant", "dirt_grassy_edge", "stone_paving", "stone_moss",
]
const TILE := 32
const COLS := 4
const ROWS := 11

const TRANSITIONS := preload("res://tools/dev/transition_tiles.gd")
const WATER := preload("res://tools/dev/water_tiles.gd")


func _init() -> void:
	var tiles: Array[Image] = []
	for name in BASE_TILE_NAMES:
		var tex: Texture2D = load("%s/%s.png" % [TILE_DIR, name])
		tiles.append(tex.get_image())
	tiles.append_array(TRANSITIONS.generate())
	tiles.append_array(WATER.generate())
	assert(tiles.size() == COLS * ROWS)

	var atlas := Image.create(TILE * COLS, TILE * ROWS, false, Image.FORMAT_RGBA8)
	for i in tiles.size():
		atlas.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, Vector2i(TILE, TILE)),
				Vector2i((i % COLS) * TILE, floori(i / float(COLS)) * TILE))

	var err := atlas.save_png("%s/forest_ground_atlas.png" % TILE_DIR)
	if err != OK:
		push_error("[atlas] save failed: %s" % err)
		quit(1)
		return
	print("[atlas] saved %s/forest_ground_atlas.png (%dx%d)" % [TILE_DIR, TILE * COLS, TILE * ROWS])
	quit()
