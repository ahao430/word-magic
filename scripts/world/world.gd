extends Node2D
## Dev forest test map: paints a deterministic 48x32 ground layout from
## the production ground tiles, chooses grass->dirt transition tiles by
## 4-bit neighbor bitmask, scatters collidable props (trees/rocks) and
## non-colliding bushes, and walls the map borders.

const MAP_CELLS := Vector2i(48, 32)
const TILE_SOURCE_ID := 0

## Atlas coordinates in forest_ground_atlas.png (4 cols x 6 rows).
## Rows 0-1: base tiles. Rows 2-5: transitions, index == side bitmask.
const GRASS_PLAIN := Vector2i(0, 0)
const GRASS_DENSE := Vector2i(1, 0)
const GRASS_FLOWERS := Vector2i(2, 0)
const DIRT_PLAIN := Vector2i(3, 0)
const DIRT_VARIANT := Vector2i(0, 1)
const STONE_PAVING := Vector2i(2, 1)
const STONE_MOSS := Vector2i(3, 1)
const TRANSITION_ROW := 2

## Bitmask for transition lookup: 1 = N neighbor grass, 2 = E, 4 = S, 8 = W.
const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8

## Prop scatter probabilities per terrain family.
const PROP_CHANCE := {
	"grass": {"tree": 0.10, "bush": 0.05, "rock": 0.02},
	"dirt": {"tree": 0.02, "bush": 0.02, "rock": 0.05},
}
const SPAWN_CELL := Vector2i(24, 16)
const SPAWN_CLEAR_RADIUS := 2.5
const PROP_SEED := 20261112

@onready var ground: TileMapLayer = $GroundLayer
@onready var props: Node2D = $Props


func _ready() -> void:
	var macro := FastNoiseLite.new()
	macro.seed = 20261111
	macro.frequency = 0.09
	var detail := FastNoiseLite.new()
	detail.seed = 99
	detail.frequency = 0.25

	var dirt_cell := _classify(macro)
	_paint_ground(dirt_cell, macro, detail)
	_scatter_props(compute_placements(dirt_cell, MAP_CELLS, PROP_SEED))
	_build_walls()


## Parent to reparent entities into so they y-sort against props.
func get_entity_parent() -> Node2D:
	return props


## Pure, testable prop placement: returns [{"type": "..", "cell": Vector2i,
## "variant": int}, ...]. Never places on stone paths, outside the map, on
## the spawn clearing, or twice on the same cell.
static func compute_placements(dirt_cell: Dictionary, map_cells: Vector2i, seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var occupied := {}
	var placements: Array[Dictionary] = []
	for y in map_cells.y:
		for x in map_cells.x:
			var cell := Vector2i(x, y)
			if cell == SPAWN_CELL or (Vector2(cell - SPAWN_CELL).length() <= SPAWN_CLEAR_RADIUS):
				continue
			if x == SPAWN_CELL.x or y == SPAWN_CELL.y:
				continue  # stone cross paths stay clear
			if occupied.has(cell):
				continue
			var family := "dirt" if dirt_cell.get(cell, false) else "grass"
			var roll := rng.randf()
			var chance: Dictionary = PROP_CHANCE[family]
			var kind := ""
			if roll < chance["tree"]:
				kind = "tree"
			elif roll < chance["tree"] + chance["bush"]:
				kind = "bush"
			elif roll < chance["tree"] + chance["bush"] + chance["rock"]:
				kind = "rock"
			if kind == "":
				continue
			occupied[cell] = true
			placements.append({"type": kind, "cell": cell, "variant": 1 + (rng.randi() % 2)})
	return placements


func _classify(macro: FastNoiseLite) -> Dictionary:
	var dirt_cell := {}
	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			dirt_cell[Vector2i(x, y)] = macro.get_noise_2d(x, y) <= -0.2
	return dirt_cell


func _paint_ground(dirt_cell: Dictionary, macro: FastNoiseLite, detail: FastNoiseLite) -> void:
	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			var cell := Vector2i(x, y)
			var coords: Vector2i
			if x == SPAWN_CELL.x or y == SPAWN_CELL.y:
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


func _scatter_props(placements: Array[Dictionary]) -> void:
	for p in placements:
		match p["type"]:
			"tree":
				_spawn_prop("Tree", p["cell"], p["variant"], "tree_%02d" % p["variant"],
						Vector2(10, 8), Vector2(0, -4))
			"rock":
				_spawn_prop("Rock", p["cell"], p["variant"], "rock_%02d" % p["variant"],
						Vector2(18, 10), Vector2(0, -5))
			"bush":
				var sprite := Sprite2D.new()
				sprite.name = "Bush_%d_%d" % [p["cell"].x, p["cell"].y]
				sprite.texture = load("res://assets/sprites/props/bush_%02d.png" % p["variant"])
				sprite.position = _cell_bottom_center(p["cell"]) + Vector2(0, -sprite.texture.get_height() * 0.5)
				props.add_child(sprite)


func _spawn_prop(prefix: String, cell: Vector2i, variant: int, tex_name: String,
		shape_size: Vector2, shape_offset: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [prefix, cell.x, cell.y]
	body.position = _cell_bottom_center(cell)
	var shape := RectangleShape2D.new()
	shape.size = shape_size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = shape_offset
	body.add_child(collider)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/props/%s.png" % tex_name)
	sprite.position = Vector2(0, -sprite.texture.get_height() * 0.5)
	body.add_child(sprite)
	props.add_child(body)


func _cell_bottom_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * 32.0 + Vector2(16.0, 32.0)


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
