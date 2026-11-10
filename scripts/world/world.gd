extends Node2D
## Dev forest test map: paints a deterministic 48x32 ground layout from
## the production ground tiles and walls the borders so the player
## cannot walk off the map. Replaced by authored maps in later phases.

const MAP_CELLS := Vector2i(48, 32)
const TILE_SOURCE_ID := 0

## Atlas coordinates in forest_ground_atlas.png (4 cols x 2 rows).
const GRASS_PLAIN := Vector2i(0, 0)
const GRASS_DENSE := Vector2i(1, 0)
const GRASS_FLOWERS := Vector2i(2, 0)
const DIRT_PLAIN := Vector2i(3, 0)
const DIRT_VARIANT := Vector2i(0, 1)
const DIRT_GRASSY_EDGE := Vector2i(1, 1)
const STONE_PAVING := Vector2i(2, 1)
const STONE_MOSS := Vector2i(3, 1)

@onready var ground: TileMapLayer = $GroundLayer


func _ready() -> void:
	_paint_ground()
	_build_walls()


func _paint_ground() -> void:
	var macro := FastNoiseLite.new()
	macro.seed = 20261111
	macro.frequency = 0.09
	var detail := FastNoiseLite.new()
	detail.seed = 99
	detail.frequency = 0.25

	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			ground.set_cell(Vector2i(x, y), TILE_SOURCE_ID, _pick_tile(x, y, macro, detail))


func _pick_tile(x: int, y: int, macro: FastNoiseLite, detail: FastNoiseLite) -> Vector2i:
	# Stone cross paths through the map center (player spawn).
	if x == 24 or y == 16:
		return STONE_MOSS if detail.get_noise_2d(x, y) > 0.45 else STONE_PAVING
	# Dense grass ring at the map border.
	if x == 0 or y == 0 or x == MAP_CELLS.x - 1 or y == MAP_CELLS.y - 1:
		return GRASS_DENSE
	var v := macro.get_noise_2d(x, y)
	if v > 0.45:
		return GRASS_FLOWERS
	if v > 0.15:
		return GRASS_PLAIN
	if v > -0.2:
		return GRASS_DENSE
	# Dirt pockets in the lowlands, occasionally a grassy edge sample.
	if detail.get_noise_2d(x, y) > 0.6:
		return DIRT_GRASSY_EDGE
	return DIRT_PLAIN if detail.get_noise_2d(x, y) > 0.0 else DIRT_VARIANT


func _build_walls() -> void:
	var map_px := Vector2(MAP_CELLS) * Vector2(ground.tile_set.tile_size)
	for side in [["left", Vector2(-16, map_px.y / 2), Vector2(32, map_px.y + 64)],
			["right", Vector2(map_px.x + 16, map_px.y / 2), Vector2(32, map_px.y + 64)],
			["top", Vector2(map_px.x / 2, -16), Vector2(map_px.x + 64, 32)],
			["bottom", Vector2(map_px.x / 2, map_px.y + 16), Vector2(map_px.x + 64, 32)]]:
		var body := StaticBody2D.new()
		body.name = "Wall_" + side[0]
		body.position = side[1]
		var shape := RectangleShape2D.new()
		shape.size = side[2]
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
