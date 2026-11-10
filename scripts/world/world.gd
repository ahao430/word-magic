extends Node2D
## Dev forest test map: paints a deterministic 48x32 ground layout from
## the production ground tiles, chooses grass->dirt transition tiles by
## 4-bit neighbor bitmask, and walls the borders so the player cannot
## walk off the map. Replaced by authored maps in later phases.

const MAP_CELLS := Vector2i(48, 32)
const TILE_SOURCE_ID := 0

## Atlas coordinates in forest_ground_atlas.png (4 cols x 6 rows).
## Rows 0-1: base tiles. Rows 2-5: transitions, index == side bitmask.
const GRASS_PLAIN := Vector2i(0, 0)
const GRASS_DENSE := Vector2i(1, 0)
const GRASS_FLOWERS := Vector2i(2, 0)
const DIRT_PLAIN := Vector2i(3, 0)
const DIRT_VARIANT := Vector2i(0, 1)
const DIRT_GRASSY_EDGE := Vector2i(1, 1)
const STONE_PAVING := Vector2i(2, 1)
const STONE_MOSS := Vector2i(3, 1)
const TRANSITION_ROW := 2

## Bitmask for transition lookup: 1 = N neighbor grass, 2 = E, 4 = S, 8 = W.
const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8

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

	# Pass 1: classify every cell as grass or dirt by macro noise.
	var dirt_cell := {}
	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			dirt_cell[Vector2i(x, y)] = macro.get_noise_2d(x, y) <= -0.2

	# Pass 2: paint. Grass cells take variety tiles; dirt cells take a
	# transition tile when any 4-neighbor is grass (bitmask atlas row).
	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			var cell := Vector2i(x, y)
			var coords: Vector2i
			if x == 24 or y == 16:
				coords = STONE_MOSS if detail.get_noise_2d(x, y) > 0.45 else STONE_PAVING
			elif x == 0 or y == 0 or x == MAP_CELLS.x - 1 or y == MAP_CELLS.y - 1:
				coords = GRASS_DENSE
			elif not dirt_cell[cell]:
				var v := macro.get_noise_2d(x, y)
				if v > 0.45:
					coords = GRASS_FLOWERS
				else:
					coords = GRASS_PLAIN if v > 0.15 else GRASS_DENSE
			else:
				var mask := _grass_neighbor_mask(cell, dirt_cell)
				if mask == 0:
					coords = DIRT_PLAIN if detail.get_noise_2d(x, y) > 0.0 else DIRT_VARIANT
				else:
					coords = Vector2i(mask % 4, TRANSITION_ROW + floori(mask / 4.0))
			ground.set_cell(cell, TILE_SOURCE_ID, coords)


func _grass_neighbor_mask(cell: Vector2i, dirt_cell: Dictionary) -> int:
	var mask := 0
	if _is_grass_cell(cell + Vector2i.UP, dirt_cell):
		mask |= BIT_N
	if _is_grass_cell(cell + Vector2i.RIGHT, dirt_cell):
		mask |= BIT_E
	if _is_grass_cell(cell + Vector2i.DOWN, dirt_cell):
		mask |= BIT_S
	if _is_grass_cell(cell + Vector2i.LEFT, dirt_cell):
		mask |= BIT_W
	return mask


func _is_grass_cell(cell: Vector2i, dirt_cell: Dictionary) -> bool:
	# Out-of-bounds counts as grass so map edges still close their fringes.
	return not dirt_cell.get(cell, false)


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
