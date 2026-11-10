extends SceneTree
## Headless test for the rune-stone puzzle: rule validation, the
## activation state machine, and the ford-building world change.
##
##   godot --headless --path . -s res://tests/puzzle_test.gd

const ICE_SPELL := {"element": "ice", "shape": "projectile", "mechanics": ["damage", "slow"],
		"parameters": {"damage": 16, "radius": 8, "speed": 260, "duration": 2.0}, "display": "寒冰箭"}
const FIRE_SPELL := {"element": "fire", "shape": "projectile", "mechanics": ["damage"],
		"parameters": {"damage": 20, "radius": 8, "speed": 300, "duration": 2.0}, "display": "火球术"}

var _failures := 0
## World memory isolation: activating the rune persists a permanent
## ford event — back up / clear / restore the real file.
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_memory_backup = ""
	if FileAccess.file_exists(SaveManager.WORLD_MEMORY_PATH):
		var mf := FileAccess.open(SaveManager.WORLD_MEMORY_PATH, FileAccess.READ)
		_memory_backup = mf.get_as_text()
		mf.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.WORLD_MEMORY_PATH))
	WorldMemory.reset()
	# --- Validator unit checks ---
	var rules := {"elements": ["water", "ice"], "shapes": [], "mechanics": []}
	_expect(PuzzleValidator.evaluate(rules, ICE_SPELL)["ok"], "ice satisfies the water-channeling rules")
	_expect(not PuzzleValidator.evaluate(rules, FIRE_SPELL)["ok"], "fire does not")
	var shape_rules := {"elements": [], "shapes": ["field"], "mechanics": []}
	_expect(not PuzzleValidator.evaluate(shape_rules, ICE_SPELL)["ok"], "projectile fails a field-only puzzle")

	# --- Integration with the real world ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var ground: TileMapLayer = world.get_node("GroundLayer")

	var stone: Node2D = null
	for child in world.get_entity_parent().get_children():
		if child.has_method("try_activate"):
			stone = child
	_expect(stone != null, "rune stone placed by the river")

	# River row 12 is water (blocking) before activation.
	var water_before := _water_cells_in_row(ground, 12)
	_expect(water_before >= 3, "row 12 has water before activation (%d cells)" % water_before)

	# Fire near the stone: rules not satisfied.
	var near_stone: Vector2 = stone.position + Vector2(24, 0)
	var r_fire: Dictionary = stone.try_activate(FIRE_SPELL, near_stone)
	_expect(not r_fire["ok"] and r_fire["reason"] == "not_satisfied",
			"fire leaves the rune dormant (%s)" % r_fire["reason"])

	# Ice far away: out of range, silent.
	var r_far: Dictionary = stone.try_activate(ICE_SPELL, stone.position + Vector2(600, 0))
	_expect(not r_far["ok"] and r_far["reason"] == "too_far", "distance gate works")

	# Ice near the stone: awakens, then the ford appears.
	var r_ice: Dictionary = stone.try_activate(ICE_SPELL, near_stone)
	_expect(r_ice["ok"] and r_ice["message"] != "", "ice awakens the rune")
	for i in 50:  # activating tween ~0.6s
		await physics_frame
	_expect(stone.state == 2, "stone reaches ACTIVATED")  # enum access via int (headless cache)
	_expect(_water_cells_in_row(ground, 12) == 0, "ford built: row 12 fully walkable")

	# Already awake: polite refusal.
	var r_again: Dictionary = stone.try_activate(ICE_SPELL, near_stone)
	_expect(not r_again["ok"] and r_again["reason"] == "already", "second activation refused")

	# Restore the developer's real world-memory file.
	if _memory_backup != "":
		var rf := FileAccess.open(SaveManager.WORLD_MEMORY_PATH, FileAccess.WRITE)
		rf.store_string(_memory_backup)
		rf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.WORLD_MEMORY_PATH))
	WorldMemory.reset()

	_finish()


func _water_cells_in_row(ground: TileMapLayer, row: int) -> int:
	var count := 0
	for x in 48:
		var data := ground.get_cell_tile_data(Vector2i(x, row))
		if data != null and data.get_collision_polygons_count(0) > 0:
			count += 1
	return count


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
