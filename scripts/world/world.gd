extends Node2D
## Dev forest test map: paints a deterministic 48x32 ground layout from
## the production ground tiles, carves a meandering river with shore
## transition tiles, scatters collidable props (trees/rocks) and
## non-colliding bushes, and walls the map borders.

const MAP_CELLS := Vector2i(64, 32)
const TILE_SOURCE_ID := 0

## 迷雾湿地 (the Misty Wetland): everything east of this column. The
## stone path (row 16) runs through the boundary gate straight into it.
const WETLAND_START := 48

## Atlas coordinates in forest_ground_atlas.png (4 cols x 11 rows).
## Rows 0-1 base, 2-5 grass->dirt transitions, 6 water surfaces,
## 7-10 land->water shore transitions (index == side bitmask).
const GRASS_PLAIN := Vector2i(0, 0)
const GRASS_DENSE := Vector2i(1, 0)
const GRASS_FLOWERS := Vector2i(2, 0)
const DIRT_PLAIN := Vector2i(3, 0)
const DIRT_VARIANT := Vector2i(0, 1)
const STONE_PAVING := Vector2i(2, 1)
const STONE_MOSS := Vector2i(3, 1)
const TRANSITION_ROW := 2
const WATER_ROW := 6
const SHORE_ROW := 7

## Bitmask for transition lookup: 1 = N neighbor, 2 = E, 4 = S, 8 = W.
const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8

## River: vertical, meandering around x ~ 9..15.
const RIVER_SEED_PHASE := 1.2
const RIVER_AMPLITUDE := 2.5
const RIVER_FREQUENCY := 0.35

## Prop scatter probabilities per terrain family.
const PROP_CHANCE := {
	"grass": {"tree": 0.10, "bush": 0.05, "rock": 0.02},
	"dirt": {"tree": 0.02, "bush": 0.02, "rock": 0.05},
}
const SPAWN_CELL := Vector2i(24, 16)
const SPAWN_CLEAR_RADIUS := 2.5
const PROP_SEED := 20261112
const SLIME_COUNT := 8
const SLIME_SEED := 777
const SLIME_MIN_SPAWN_DISTANCE := 6.0

## Water-channeling puzzle: rune stone beside the river; activating it
## builds a stone ford across FORD_ROW.
const RUNE_STONE_CELL := Vector2i(13, 12)
const FORD_ROW := 12

## Boss arena: the Slime King holds a cleared clearing in the far NE.
const BOSS_CELL := Vector2i(38, 8)

## Wetland landmarks: the boundary gate pillars flank the path row, and
## the elite slime holds the deep swamp.
const GATE_N_CELL := Vector2i(WETLAND_START, 15)
const GATE_S_CELL := Vector2i(WETLAND_START, 17)
const ELITE_CELL := Vector2i(58, 10)

## The blessing spring's preferred spot (first land cell found from
## here, so ponds can never bury it).
const SPRING_CELL := Vector2i(60, 22)

## The Forest Keeper stands beside the path, just west of the gate.
const KEEPER_CELL := Vector2i(46, 15)

## Procedural layout seed (AGENTS.md §11 "map Seed for procedural
## reconstruction"). 0 = the historical legacy layout (byte-identical
## to every world before seeds existed — old saves stay exact); any
## other value drives terrain noise + prop/slime scatter. One seed
## derives the whole layout; POIs (gate/spring/keeper/boss/rune/elite)
## stay at their handcrafted cells on every seed.
var layout_seed := 0

const LEGACY_MACRO_SEED := 20261111
const LEGACY_PROP_SEED := 20261112
const LEGACY_SLIME_SEED := 777


func _macro_seed() -> int:
	return layout_seed if layout_seed != 0 else LEGACY_MACRO_SEED


func _west_prop_seed() -> int:
	return layout_seed + 1 if layout_seed != 0 else LEGACY_PROP_SEED


func _slime_scatter_seed() -> int:
	return layout_seed + 2 if layout_seed != 0 else LEGACY_SLIME_SEED

## Fired once when the boss dies (the boss_defeated flag + save tier
## record it; this notifies the HUD).
signal boss_died

## Fired once per save lifetime when the player first enters the
## wetland (permanent world memory).
signal region_discovered(region_name: String)

## Fired when the wetland elite dies (main grants the swamp heart).
signal elite_died

## Fired when an expedition echo falls (seconds, best, improved).
signal expedition_completed(seconds: float, best: float, improved: bool)


@onready var ground: TileMapLayer = $GroundLayer
@onready var props: Node2D = $Props

## Session world state (saved/restored with the session save).
var ford_built := false
var boss_defeated := false

## Permanent region progress (replayed from world memory on load).
var wetland_discovered := false

## Region poll accumulator: bias + discovery checks run at 2 Hz.
var _region_acc := 0.0

## 远征 (expedition) state: in-memory on purpose — a restart aborts the
## run and the keeper simply re-offers. Best times live in the
## permanent tier; the run itself does not.
var expedition_active := false
var _expedition_time := 0.0

## Open-water shimmer: the 4 surface variants cycle slowly; per-cell
## phase offset keeps the swap from looking like a global strobe.
const WATER_CYCLE_TIME := 0.45
var _water_anim_acc := 0.0
var _water_cycle := 0
var _open_water: Array[Vector2i] = []

## Tree sway: canopies rotate a couple of degrees around a per-tree
## phase so the forest breathes without synchronization.
var _sway_time := 0.0
var _sway_targets: Array = []  # [sprite, phase] pairs, built lazily


func _ready() -> void:
	# Title's "new game" hands a fresh random seed over before the first
	# build (loads restore their own seed later via apply_layout_seed).
	var pending: int = GameManager.consume_layout_seed()
	if pending != 0 and layout_seed == 0:
		layout_seed = pending
	_build_layout()
	_build_walls()
	_setup_weather()
	_apply_world_memory()


## Seed-to-world layout pass (re-entrant: apply_layout_seed wipes the
## props layer and runs this again on the same node).
func _build_layout() -> void:
	var macro := FastNoiseLite.new()
	macro.seed = _macro_seed()
	macro.frequency = 0.09
	var detail := FastNoiseLite.new()
	detail.seed = 99
	detail.frequency = 0.25

	var dirt_cell := _classify(macro)
	var water_cell := river_cells()
	for cell in wetland_pond_cells():
		water_cell[cell] = true
	_paint_ground(dirt_cell, water_cell, macro, detail)
	# Two-pass prop scatter: the legacy pass keeps its historical
	# sequence (seed 0 worlds stay byte-identical); a custom seed shifts
	# BOTH passes deterministically, and the wetland always rides its
	# own sequence.
	var west_placements: Array[Dictionary] = compute_placements(dirt_cell,
			river_cells(), Vector2i(WETLAND_START, MAP_CELLS.y), _west_prop_seed())
	var east_placements: Array[Dictionary] = compute_placements(dirt_cell,
			wetland_pond_cells(), Vector2i(MAP_CELLS.x - WETLAND_START, MAP_CELLS.y),
			_west_prop_seed() + 1, Vector2i(WETLAND_START, 0))
	_scatter_props(west_placements + east_placements)
	_scatter_slimes(dirt_cell, water_cell)
	_scatter_wetland_slimes(water_cell)
	_scatter_wetland_flies(water_cell)
	_spawn_boss()
	_setup_puzzle()
	_spawn_gate()
	_spawn_spring(water_cell)
	_spawn_keeper()
	_setup_water_shimmer(water_cell)
	_setup_waterfall(water_cell)


## Swap to a different seed and rebuild the layout in place (session
## load path). Dying children are renamed so re-spawned POI names stay
## unique while the queue drains.
func apply_layout_seed(new_seed: int) -> void:
	if new_seed == layout_seed:
		return
	layout_seed = new_seed
	var n := 0
	for child in props.get_children():
		# The player was reparented into props and must survive every
		# reseed (a load with a different seed would otherwise erase
		# them — caught by the playthrough acceptance run).
		if child.name == "Player":
			continue
		child.name = "ZzDead%d" % n
		n += 1
		child.queue_free()
	_sway_targets = []
	_open_water = []
	_build_layout()
	_apply_world_memory()


## Replay permanent deltas recorded in earlier runs (the deterministic
## seed rebuild + delta replay model, AGENTS.md §11): the world is
## identical for everyone, then remembered facts are applied on top.
func _apply_world_memory() -> void:
	if WorldMemory.has_event(WorldMemory.EVENT_BOSS):
		boss_defeated = true
		var boss := get_boss()
		if boss != null and is_instance_valid(boss):
			boss.queue_free()
	if WorldMemory.has_event(WorldMemory.EVENT_RUNE):
		for child in props.get_children():
			if child.has_method("force_activate"):
				child.call("force_activate")
	if WorldMemory.has_event(WorldMemory.EVENT_FORD):
		build_ford()
	if WorldMemory.has_event(WorldMemory.EVENT_REGION):
		wetland_discovered = true
	if WorldMemory.has_event(WorldMemory.EVENT_ELITE):
		var elite := get_entity_parent().get_node_or_null("SlimeElite_%d_%d" % [ELITE_CELL.x, ELITE_CELL.y])
		if elite != null:
			elite.queue_free()
	if WorldMemory.has_event(WorldMemory.EVENT_SPRING):
		var spring := get_entity_parent().get_node_or_null("SwampSpring")
		if spring != null:
			spring.call("force_used")


## Parent to reparent entities into so they y-sort against props.
func get_entity_parent() -> Node2D:
	return props


## World size in pixels — the camera clamps its limits to this.
func map_pixel_size() -> Vector2:
	return Vector2(MAP_CELLS) * Vector2(ground.tile_set.tile_size)


## True when the ground tile at `world_pos` blocks movement (the river
## family; the ford's stone tiles carry no collision, so a built ford
## reads as passable). Enemies probe ahead with this to stay out of the
## water — the weather-aware enemy AI (slime "畏水").
func is_blocked_ground(world_pos: Vector2) -> bool:
	var cell: Vector2i = ground.local_to_map(ground.to_local(world_pos))
	var data := ground.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) > 0


## Region name for the HUD and feature gates — the boundary IS the gate.
static func region_name_at(world_pos: Vector2) -> String:
	return "迷雾湿地" if world_pos.x >= float(WETLAND_START) * 32.0 else "森林"


## Deterministic wetland ponds: 2x2 cell blocks hashed from block
## coordinates (~26% water). The stone path row overrides in painting,
## so the road through the swamp reads as a boardwalk.
static func wetland_pond_cells() -> Dictionary:
	var ponds := {}
	for by in range(1, 15):
		for bx in range(25, 31):
			var h := absf(fmod(sin(bx * 127.1 + by * 311.7) * 43758.5453, 1.0))
			if h < 0.30:
				for dy in 2:
					for dx in 2:
						ponds[Vector2i(bx * 2 + dx, by * 2 + dy)] = true
	return ponds


## Cells covered by the meandering river (3 wide, widening to 5).
static func river_cells() -> Dictionary:
	var water := {}
	for y in 32:
		var center := 12.0 + RIVER_AMPLITUDE * sin(y * RIVER_FREQUENCY + RIVER_SEED_PHASE)
		var half := 1
		if sin(y * 0.5 + 0.3) > 0.7:
			half = 2
		for dx in range(-half, half + 1):
			water[Vector2i(int(round(center)) + dx, y)] = true
	return water


## Pure, testable prop placement: returns [{"type": "..", "cell": Vector2i,
## "variant": int}, ...]. Never places in water, on stone paths, outside
## the map, in the spawn clearing, or twice on the same cell.
static func compute_placements(dirt_cell: Dictionary, water_cell: Dictionary,
		map_cells: Vector2i, seed: int, origin := Vector2i.ZERO) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var occupied := {}
	var placements: Array[Dictionary] = []
	for y in map_cells.y:
		for x in map_cells.x:
			var cell := origin + Vector2i(x, y)
			if water_cell.has(cell):
				continue
			if cell == SPAWN_CELL or (Vector2(cell - SPAWN_CELL).length() <= SPAWN_CLEAR_RADIUS):
				continue
			if cell.x == SPAWN_CELL.x or cell.y == SPAWN_CELL.y:
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
			var cell := Vector2i(x, y)
			var n := macro.get_noise_2d(x, y)
			# The wetland is muddier: a far wider dirt threshold.
			if x >= WETLAND_START:
				dirt_cell[cell] = n <= 0.15
			else:
				dirt_cell[cell] = n <= -0.2
	return dirt_cell


func _paint_ground(dirt_cell: Dictionary, water_cell: Dictionary,
		macro: FastNoiseLite, detail: FastNoiseLite) -> void:
	for y in MAP_CELLS.y:
		for x in MAP_CELLS.x:
			var cell := Vector2i(x, y)
			var coords: Vector2i
			if x == SPAWN_CELL.x or y == SPAWN_CELL.y:
				# Stone paths override terrain: the horizontal one doubles
				# as the walkable ford across the river.
				coords = STONE_MOSS if detail.get_noise_2d(x, y) > 0.45 else STONE_PAVING
			elif water_cell.has(cell):
				var mask := _land_neighbor_mask(cell, dirt_cell, water_cell)
				if mask == 0:
					coords = Vector2i(int(absf(detail.get_noise_2d(x, y) * 4.0)) % 4, WATER_ROW)
				else:
					coords = Vector2i(mask % 4, SHORE_ROW + floori(mask / 4.0))
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


func _process(delta: float) -> void:
	_sway_time += delta
	_sway_trees()
	_poll_region(delta)
	if expedition_active:
		_expedition_time += delta
	_water_anim_acc += delta
	if _water_anim_acc < WATER_CYCLE_TIME:
		return
	_water_anim_acc = 0.0
	_water_cycle = (_water_cycle + 1) % 4
	for cell in _open_water:
		# Skip cells the ford replaced (their atlas row left row 6);
		# this also keeps the shimmer save/restore-safe.
		if ground.get_cell_atlas_coords(cell).y != WATER_ROW:
			continue
		var variant := (cell.x + cell.y + _water_cycle) % 4
		ground.set_cell(cell, TILE_SOURCE_ID, Vector2i(variant, WATER_ROW))


func _sway_trees() -> void:
	if _sway_targets.is_empty():
		for child in props.get_children():
			if child.name.begins_with("Tree_"):
				var idx := child.get_child_count() - 1
				if idx < 0:
					continue
				var sprite: Node = child.get_child(idx)
				if sprite is Sprite2D:
					var parts := child.name.split("_")
					var phase := (int(parts[1]) * 13 + int(parts[2]) * 7) * 0.37
					_sway_targets.append([sprite, phase])
	for pair in _sway_targets:
		# Prop spawners queue_free trees after this cache was built; a
		# freed object must never cross the typed assignment.
		if not is_instance_valid(pair[0]):
			continue
		var sprite: Sprite2D = pair[0]
		sprite.rotation = sin(_sway_time * 1.4 + pair[1]) * 0.022


func _setup_water_shimmer(water_cell: Dictionary) -> void:
	for cell in water_cell.keys():
		var mask := _land_neighbor_mask(cell, {}, water_cell)
		if mask == 0:
			_open_water.append(cell)


## Weather runtime (AGENTS.md §10.1): the sole writer of the Weather
## statics; session-saved with the world tier.
func _setup_weather() -> void:
	var weather: Node = load("res://scripts/world/weather_system.gd").new()
	weather.name = "WeatherSystem"
	add_child(weather)


func get_weather() -> Node:
	return get_node_or_null("WeatherSystem")


func _setup_waterfall(water_cell: Dictionary) -> void:
	## Animated waterfall curtain at the river's source (top rows).
	var shader: Shader = load("res://shaders/waterfall_scroll.gdshader")
	var tex: Texture2D = load("res://assets/sprites/effects/waterfall_32x64.png")
	for cell in water_cell.keys():
		if cell.y != 0:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Waterfall_%d" % cell.x
		sprite.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = shader
		sprite.material = mat
		sprite.position = Vector2(cell) * 32.0 + Vector2(16.0, 48.0)
		sprite.scale = Vector2(1.0, 1.5)  # 3 tiles tall
		props.add_child(sprite)


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


func _land_neighbor_mask(cell: Vector2i, dirt_cell: Dictionary, water_cell: Dictionary) -> int:
	## Mask bits set for non-water neighbors (grass or dirt = land).
	var mask := 0
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for offset in dirs:
		var n := cell + offset
		if not water_cell.has(n):
			mask |= _bit_for(offset)
	return mask


func _bit_for(offset: Vector2i) -> int:
	if offset == Vector2i.UP:
		return BIT_N
	if offset == Vector2i.RIGHT:
		return BIT_E
	if offset == Vector2i.DOWN:
		return BIT_S
	return BIT_W


func _setup_puzzle() -> void:
	## Place the rune stone on its bank cell, freeing the cell of any
	## scattered prop so the two never overlap.
	var stone: Node2D = load("res://scenes/puzzles/rune_stone.tscn").instantiate()
	stone.name = "RuneStone"
	for child in props.get_children():
		var is_blocking_prop: bool = child.name.begins_with("Tree_") or child.name.begins_with("Rock_")
		if is_blocking_prop and Vector2i(int(child.position.x) / 32, int(child.position.y - 16) / 32) == RUNE_STONE_CELL:
			child.queue_free()
	stone.setup(self, RUNE_STONE_CELL)
	props.add_child(stone)


## Forward a successful spell cast to puzzle nodes near the caster.
## Returns the first human-readable puzzle reaction ("" when silent).
func on_spell_cast(spell: Dictionary, cast_position: Vector2) -> String:
	for child in props.get_children():
		if child.has_method("try_activate"):
			var reaction: Dictionary = child.try_activate(spell, cast_position)
			if reaction.get("message", "") != "":
				return reaction["message"]
	return ""


## The awakened rune channels the river: water tiles on FORD_ROW turn
## into walkable stone (tile swap removes the water collision too).
## The awakened rune + ford are permanent world facts once built.
func build_ford() -> void:
	if ford_built:
		return
	ford_built = true
	WorldMemory.record_and_persist(WorldMemory.EVENT_FORD)
	WorldMemory.record_and_persist(WorldMemory.EVENT_RUNE)
	var water := river_cells()
	for x in MAP_CELLS.x:
		var cell := Vector2i(x, FORD_ROW)
		if water.has(cell):
			var coords := STONE_MOSS if x % 3 == 0 else STONE_PAVING
			ground.set_cell(cell, TILE_SOURCE_ID, coords)


## --- Session save/load (world tier) ---

## Capture: rune state, ford, which slimes are still alive (the scatter
## is deterministic, so names identify individuals), and the boss tier.
func capture_state() -> Dictionary:
	var rune_state := 0
	var alive_slimes := []
	for child in props.get_children():
		if child.has_method("try_activate"):
			rune_state = child.state
		elif child is CharacterBody2D and (child.name.begins_with("Slime") or child.name.begins_with("SwampFly")):
			alive_slimes.append(child.name)
	var weather := get_weather()
	var weather_state: Dictionary = weather.capture_state() if weather != null else {}
	return {"rune_state": rune_state, "ford_built": ford_built,
			"alive_slimes": alive_slimes, "boss": _capture_boss(),
			"weather": weather_state, "layout_seed": layout_seed}


func _capture_boss() -> Dictionary:
	var boss_state := {"defeated": boss_defeated, "alive": false}
	var boss := get_boss()
	if boss != null and is_instance_valid(boss) and bool(boss.get("alive")):
		boss_state["alive"] = true
		boss_state["hp"] = float(boss.get("hp"))
		boss_state["x"] = boss.global_position.x
		boss_state["y"] = boss.global_position.y
	return boss_state


## Restore after the deterministic world rebuild: replay the ford,
## re-awaken the rune silently, remove slimes that died before saving,
## and re-seat the boss (position/hp, or gone if he was defeated).
func restore_state(data: Dictionary) -> void:
	# Old saves carry no seed: 0 keeps the legacy layout untouched.
	var saved_seed: int = int(data.get("layout_seed", 0))
	if saved_seed != layout_seed:
		apply_layout_seed(saved_seed)
	if data.get("ford_built", false):
		build_ford()
		for child in props.get_children():
			if child.has_method("force_activate"):
				child.call("force_activate")
	var alive: Array = data.get("alive_slimes", [])
	for child in props.get_children():
		if child is CharacterBody2D and (child.name.begins_with("Slime") or child.name.begins_with("SwampFly")):
			if not alive.has(child.name):
				child.queue_free()
	if data.has("weather") and not data["weather"].is_empty():
		var weather := get_weather()
		if weather != null:
			weather.apply_state(data["weather"])
	var boss_data: Dictionary = data.get("boss", {})
	boss_defeated = bool(boss_data.get("defeated", false))
	var boss := get_boss()
	if boss == null or not is_instance_valid(boss):
		return
	if not boss_data.get("alive", true):
		boss.queue_free()
		return
	boss.set("hp", float(boss_data.get("hp", 120.0)))
	boss.global_position = Vector2(float(boss_data.get("x", boss.global_position.x)),
			float(boss_data.get("y", boss.global_position.y)))


func _scatter_slimes(dirt_cell: Dictionary, water_cell: Dictionary) -> void:
	## Deterministic slime scatter: land cells away from the spawn area.
	var rng := RandomNumberGenerator.new()
	rng.seed = _slime_scatter_seed()
	var placed := 0
	for y in MAP_CELLS.y:
		if placed >= SLIME_COUNT:
			break
		for x in MAP_CELLS.x:
			if placed >= SLIME_COUNT:
				break
			if x >= WETLAND_START:
				break  # the forest's own scatter never crosses the gate
			var cell := Vector2i(x, y)
			if water_cell.has(cell) or dirt_cell.get(cell, false):
				continue
			if x == SPAWN_CELL.x or y == SPAWN_CELL.y:
				continue
			if Vector2(cell - SPAWN_CELL).length() < SLIME_MIN_SPAWN_DISTANCE:
				continue
			if rng.randf() < 0.02:
				var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
				slime.name = "Slime_%d_%d" % [cell.x, cell.y]
				slime.position = Vector2(cell) * 32.0 + Vector2(16.0, 24.0)
				props.add_child(slime)
				slime.connect("died", _on_slime_died)
				placed += 1


## Wetland population: three regular slimes on eastern land cells plus
## one deep-swamp elite (60hp, swollen). Names follow the "Slime*"
## convention so the session save's alive-list covers them too.
func _scatter_wetland_slimes(water_cell: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8888
	var placed := 0
	for y in range(MAP_CELLS.y - 1, -1, -1):
		if placed >= 3:
			break
		for x in range(MAP_CELLS.x - 1, WETLAND_START, -1):
			if placed >= 3:
				break
			var cell := Vector2i(x, y)
			if water_cell.has(cell) or x == SPAWN_CELL.x or y == SPAWN_CELL.y:
				continue
			if Vector2(cell - Vector2i(ELITE_CELL)).length() < 4.0:
				continue
			if rng.randf() < 0.05:
				var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
				slime.name = "Slime_%d_%d" % [cell.x, cell.y]
				slime.position = Vector2(cell) * 32.0 + Vector2(16.0, 24.0)
				props.add_child(slime)
				slime.connect("died", _on_slime_died)
				placed += 1
	var elite: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	elite.name = "SlimeElite_%d_%d" % [ELITE_CELL.x, ELITE_CELL.y]
	elite.position = Vector2(ELITE_CELL) * 32.0 + Vector2(16.0, 24.0)
	props.add_child(elite)
	elite.set("hp", 60.0)
	elite.scale = Vector2(1.3, 1.3)
	elite.get_node("SlimeSprite").modulate = Color(0.55, 0.75, 0.5)
	# The heart of the swamp: main grants the permanent upgrade on died.
	elite.connect("died", _on_elite_died)


## Wetland flies: four pests buzzing over the ponds (they ignore water
## entirely — crossing rivers is their whole identity).
func _scatter_wetland_flies(water_cell: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 3 if layout_seed != 0 else 4242
	var placed := 0
	for cell: Vector2i in water_cell.keys():
		if placed >= 4:
			break
		if cell.x < WETLAND_START or cell.y == SPAWN_CELL.y:
			continue
		if rng.randf() < 0.06:
			var fly: CharacterBody2D = load("res://scenes/enemies/swamp_fly.tscn").instantiate()
			fly.name = "SwampFly_%d_%d" % [cell.x, cell.y]
			fly.position = Vector2(cell) * 32.0 + Vector2(16.0, 16.0)
			props.add_child(fly)
			fly.connect("died", _on_fly_died)
			placed += 1


func _on_elite_died() -> void:
	# Only the ORIGINAL elite lands here (echoes connect elsewhere), so
	# the heart is granted exactly once and echoes never stack it.
	WorldMemory.record_and_persist(WorldMemory.EVENT_ELITE)
	elite_died.emit()


## The blessing spring takes the first land cell found from SPRING_CELL
## (ponds are deterministic, so the pick is too).
func _spawn_spring(water_cell: Dictionary) -> void:
	var cell := SPRING_CELL
	while water_cell.has(cell) or cell.y == SPAWN_CELL.y:
		cell += Vector2i(0, -1)
	for child in props.get_children():
		var is_blocking_prop: bool = child.name.begins_with("Tree_") or child.name.begins_with("Rock_")
		if is_blocking_prop and Vector2i(int(child.position.x) / 32, int(child.position.y - 16) / 32) == cell:
			child.queue_free()
	var spring: Node2D = load("res://scripts/world/swamp_spring.gd").new()
	spring.name = "SwampSpring"
	spring.position = Vector2(cell) * 32.0 + Vector2(16.0, 20.0)
	props.add_child(spring)


## Boundary gate: two stone pillars flanking the path row — the road
## into the wetland passes between them.
func _spawn_gate() -> void:
	for pair in [["Gate_Pillar_N", GATE_N_CELL], ["Gate_Pillar_S", GATE_S_CELL]]:
		for child in props.get_children():
			var is_blocking_prop: bool = child.name.begins_with("Tree_") or child.name.begins_with("Rock_")
			if is_blocking_prop and Vector2i(int(child.position.x) / 32, int(child.position.y - 16) / 32) == pair[1]:
				child.queue_free()
		var pillar := StaticBody2D.new()
		pillar.name = pair[0]
		pillar.position = _cell_bottom_center(pair[1])
		var shape := RectangleShape2D.new()
		shape.size = Vector2(14, 40)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = Vector2(0, -20)
		pillar.add_child(collider)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/props/rock_01.png")
		sprite.scale = Vector2(0.9, 2.4)
		sprite.position = Vector2(0, -22)
		pillar.add_child(sprite)
		props.add_child(pillar)


## Ground slime fell: one for the journey tally.
func _on_slime_died() -> void:
	WorldMemory.bump_counter("slain_slimes")


## A swamp fly dropped: its own line on the journey page.
func _on_fly_died() -> void:
	WorldMemory.bump_counter("slain_flies")


## 远征 echo: a fresh guardian of the swamp heart springs up at the
## throne cell for the repeatable challenge.
func spawn_elite_echo() -> void:
	var echo: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	echo.name = "SlimeEliteEcho"
	echo.position = Vector2(ELITE_CELL) * 32.0 + Vector2(16.0, 24.0)
	echo.set("hp", 60.0)
	echo.scale = Vector2(1.3, 1.3)
	echo.get_node("SlimeSprite").modulate = Color(0.75, 0.6, 0.9)
	props.add_child(echo)
	# Separate handler: echoes settle the run, the ORIGINAL elite's
	# death grants the heart — never the reverse.
	echo.connect("died", _on_echo_died)


func _on_echo_died() -> void:
	WorldMemory.bump_counter("expedition_runs")
	expedition_active = false
	var best := -1.0
	var prior: Dictionary = WorldMemory.get_event(WorldMemory.EVENT_EXPEDITION)
	if not prior.is_empty():
		best = float(prior.get("best_seconds", -1.0))
	var improved := best < 0.0 or _expedition_time < best
	if improved:
		WorldMemory.record_and_persist(WorldMemory.EVENT_EXPEDITION,
				{"best_seconds": _expedition_time})
		best = _expedition_time
	expedition_completed.emit(_expedition_time, best, improved)


## The Keeper: first NPC, solid, standing by the gate.
func _spawn_keeper() -> void:
	for child in props.get_children():
		var is_blocking_prop: bool = child.name.begins_with("Tree_") or child.name.begins_with("Rock_")
		if is_blocking_prop and Vector2i(int(child.position.x) / 32, int(child.position.y - 16) / 32) == KEEPER_CELL:
			child.queue_free()
	var keeper: StaticBody2D = load("res://scripts/world/keeper.gd").new()
	keeper.name = "Keeper"
	keeper.position = _cell_bottom_center(KEEPER_CELL)
	props.add_child(keeper)


## 2 Hz region poll: feed the weather system its region bias and fire
## the one-shot wetland discovery (permanent world memory).
func _poll_region(delta: float) -> void:
	_region_acc += delta
	if _region_acc < 0.5:
		return
	_region_acc = 0.0
	var player: CharacterBody2D = null
	for child in props.get_children():
		if child is CharacterBody2D and child.name == "Player":
			player = child
			break
	if player == null:
		return
	var system := get_weather()
	if system != null:
		system.region_bias = "wetland" if player.global_position.x >= float(WETLAND_START) * 32.0 else "forest"
	if not wetland_discovered and system != null and system.region_bias == "wetland":
		wetland_discovered = true
		WorldMemory.record_and_persist(WorldMemory.EVENT_REGION)
		region_discovered.emit("迷雾湿地")


func _spawn_boss() -> void:
	## Clear a small arena around the throne cell so the king is visible
	## and reachable, then seat him (feet just above the tile bottom).
	for child in props.get_children():
		var is_blocking_prop: bool = child.name.begins_with("Tree_") or child.name.begins_with("Rock_")
		if not is_blocking_prop:
			continue
		var cell := Vector2i(int(child.position.x) / 32, int(child.position.y - 16) / 32)
		if absi(cell.x - BOSS_CELL.x) <= 1 and absi(cell.y - BOSS_CELL.y) <= 1:
			child.queue_free()
	var boss: CharacterBody2D = load("res://scenes/enemies/boss_slime.tscn").instantiate()
	boss.name = "BossSlime"
	boss.position = Vector2(BOSS_CELL) * 32.0 + Vector2(16.0, 26.0)
	props.add_child(boss)
	# String connect: the boss script's signal is invisible to the typed
	# CharacterBody2D reference.
	boss.connect("died", _on_boss_died)


func _on_boss_died() -> void:
	boss_defeated = true
	boss_died.emit()
	# Permanent world progress: the king stays dead across restarts.
	WorldMemory.record_and_persist(WorldMemory.EVENT_BOSS)


## Boss accessor for the HUD health bar (duck-typed reads keep this
## independent of the boss script class).
func get_boss() -> Node2D:
	var boss := props.get_node_or_null("BossSlime")
	return boss


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
	# Soft ground shadow first so the prop renders on top of it.
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/effects/shadow_16x8.png")
	shadow.modulate = Color(1, 1, 1, 0.7)
	shadow.position = Vector2(0, -2)
	if prefix == "Tree":
		shadow.scale = Vector2(2.2, 1.1)
	else:
		shadow.scale = Vector2(1.4, 0.9)
	body.add_child(shadow)
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
