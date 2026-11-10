extends SceneTree
## Headless test for World.compute_placements (pure static function).
##
##   godot --headless --path . -s res://tests/prop_placement_test.gd
##
## Verifies determinism and the placement invariants: inside the map,
## never on the stone paths or the spawn clearing, no duplicate cells,
## and a sane density.

const MAP := Vector2i(48, 32)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_script := load("res://scripts/world/world.gd")

	# Synthetic terrain: all grass except a dirt blob around (10, 8).
	var dirt := {}
	for y in range(5, 12):
		for x in range(7, 14):
			dirt[Vector2i(x, y)] = true

	var a: Array = world_script.compute_placements(dirt, MAP, 20261112)
	var b: Array = world_script.compute_placements(dirt, MAP, 20261112)
	_expect(a.hash() == b.hash() and a.size() == b.size(), "same seed -> same placements")

	var cells := {}
	var ok_cells := true
	var count_by_type := {"tree": 0, "rock": 0, "bush": 0}
	for p in a:
		var cell: Vector2i = p["cell"]
		if not cells.has(cell):
			cells[cell] = true
		else:
			ok_cells = false
		var in_bounds := cell.x >= 0 and cell.y >= 0 and cell.x < MAP.x and cell.y < MAP.y
		var off_path := cell.x != 24 and cell.y != 16
		var clear_of_spawn := Vector2(cell - Vector2i(24, 16)).length() > 2.5
		if not (in_bounds and off_path and clear_of_spawn):
			ok_cells = false
		count_by_type[p["type"]] += 1

	_expect(ok_cells, "all placements in-bounds, off-path, spawn-clear, unique")
	_expect(a.size() > 40, "placements non-empty and sane density (%d props)" % a.size())
	_expect(count_by_type["tree"] > 10, "trees present (%d)" % count_by_type["tree"])

	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("PASS  " + what)
	else:
		_failures += 1
		print("FAIL  " + what)
