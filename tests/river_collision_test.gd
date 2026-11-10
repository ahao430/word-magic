extends SceneTree
## Headless integration test: the river blocks movement except at the
## stone ford. Walks west along row 15 (off-path) from a prop-free cell
## and asserts the body stops tight at the river's east bank; walks
## west along row 16 (ford) and asserts the crossing is passable all
## the way past the west bank.
##
##   godot --headless --path . -s res://tests/river_collision_test.gd

const WALK_FRAMES := 300

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var ground: TileMapLayer = world.get_node("GroundLayer")

	# Eastmost water cell on row 15 (the river's east bank edge).
	var east_water_x := -1
	for x in range(47, -1, -1):
		var data := ground.get_cell_tile_data(Vector2i(x, 15))
		if data != null and data.get_collision_polygons_count(0) > 0:
			east_water_x = x
			break
	_expect(east_water_x > 0, "river found on row 15 (east water cell %d)" % east_water_x)
	if east_water_x < 0:
		_finish()
		return
	var bank_px := float(east_water_x + 1) * 32.0

	# --- Off-path row: blocked at the bank. ---
	var start_cell := _find_clear_start(world, east_water_x)
	_expect(start_cell.x > 0, "prop-free start cell found west of spawn (cell %s)" % start_cell)
	if start_cell.x <= 0:
		_finish()
		return

	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(start_cell.x * 32 + 16, 15 * 32 + 16)
	world.get_entity_parent().add_child(player)
	await physics_frame
	var start_x := player.global_position.x
	Input.action_press("move_left")
	for i in WALK_FRAMES:
		await physics_frame
	Input.action_release("move_left")
	var blocked_at := player.global_position.x
	_expect(blocked_at > bank_px - 2.0, "blocked before river (x %.1f > bank %.1f)" % [blocked_at, bank_px])
	_expect(blocked_at - bank_px < 20.0, "stopped tight at the bank (gap %.1f px)" % (blocked_at - bank_px))
	_expect(start_x - blocked_at > 20.0, "did walk west first (%.1f px)" % (start_x - blocked_at))

	# --- Ford row: the crossing is fully passable to the west bank. ---
	player.position = Vector2(24 * 32 + 16, 16 * 32 + 16)
	await physics_frame
	var ford_start := player.global_position.x
	Input.action_press("move_left")
	for i in WALK_FRAMES:
		await physics_frame
	Input.action_release("move_left")
	# West bank: first non-water cell west of the river on row 16.
	var west_bank_px := 0.0
	for x in range(east_water_x, -1, -1):
		var d := ground.get_cell_tile_data(Vector2i(x, 16))
		if d == null or d.get_collision_polygons_count(0) == 0:
			west_bank_px = float(x + 1) * 32.0
			break
	_expect(player.global_position.x < west_bank_px,
			"ford crossed to west of river (x %.1f < %.1f)" % [player.global_position.x, west_bank_px])

	_finish()


## First cell east of the bank on row 15 whose 32px square contains no
## prop body (props sit at a cell's bottom-center).
func _find_clear_start(world: Node2D, east_water_x: int) -> Vector2i:
	for x in range(east_water_x + 2, 24):
		var cell := Vector2i(x, 15)
		var occupied := false
		for child in world.get_entity_parent().get_children():
			if child is StaticBody2D:
				var body: StaticBody2D = child
				if Vector2i(int(body.position.x) / 32, int(body.position.y - 16) / 32) == cell:
					occupied = true
					break
		if not occupied:
			return cell
	return Vector2i.ZERO


func _finish() -> void:
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
