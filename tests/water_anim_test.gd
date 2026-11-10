extends SceneTree
## Headless test for the water animation: open-water surface cells
## cycle their atlas variant over time, the waterfall curtain exists
## with the scroll shader at the river source, and ford-replaced cells
## are never overwritten by the shimmer.
##
##   godot --headless --path . -s res://tests/water_anim_test.gd

var _failures := 0
## World memory isolation: the ford-safety check below activates the
## rune, which persists a permanent event — back up / clear / restore.
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
	# --- Waterfall texture ---
	var tex: Texture2D = load("res://assets/sprites/effects/waterfall_32x64.png")
	_expect(tex != null and Vector2i(tex.get_size()) == Vector2i(32, 64),
			"waterfall texture 32x64")
	if tex != null:
		var img := tex.get_image()
		var blue := 0
		var total := 0
		for y in range(0, 64, 4):
			for x in range(0, 32, 4):
				total += 1
				var c := img.get_pixel(x, y)
				if c.b > c.r and c.b > c.g:
					blue += 1
		_expect(float(blue) / float(total) > 0.9, "waterfall is blue-dominant")

	# --- Shimmer + waterfall in the live world ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var ground: TileMapLayer = world.get_node("GroundLayer")

	# Find an open-water cell (atlas row 6).
	var open_cell := Vector2i(-1, -1)
	var waterfall_count := 0
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("Waterfall_"):
			waterfall_count += 1
	for y in range(2, 30):
		for x in range(6, 20):
			if ground.get_cell_atlas_coords(Vector2i(x, y)).y == 6:
				open_cell = Vector2i(x, y)
				break
		if open_cell.x > 0:
			break
	_expect(open_cell.x > 0, "open-water cell found %s" % open_cell)
	_expect(waterfall_count >= 3, "waterfall curtains at the source (%d)" % waterfall_count)

	# The waterfall uses the scroll shader.
	var has_shader := false
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("Waterfall_") and child.material is ShaderMaterial:
			has_shader = child.material.shader != null
	_expect(has_shader, "waterfall runs the scroll shader")

	# Shimmer: the variant column changes across cycles.
	var seen := {}
	for i in 100:  # ~1.6s at 60fps
		await physics_frame
		if open_cell.x > 0:
			seen[ground.get_cell_atlas_coords(open_cell).x] = true
	_expect(seen.size() >= 2, "open water cycles variants (saw %s)" % str(seen.keys()))

	# Ford safety: activate the rune, then let shimmer tick — the ford
	# tiles must remain stone (atlas row 1), never reverted to water.
	var stone: Node2D = null
	for child in world.get_entity_parent().get_children():
		if child.has_method("try_activate"):
			stone = child
	var ice: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup("寒冰箭"))["spell"]
	world.on_spell_cast(ice, stone.position + Vector2(10, 0))
	for i in 60:
		await physics_frame
	var ford_intact := true
	for x in range(48):
		var coords := ground.get_cell_atlas_coords(Vector2i(x, 12))
		if ground.get_cell_tile_data(Vector2i(x, 12)) != null and coords.y == 6:
			ford_intact = false
	_expect(ford_intact, "shimmer never reverts ford tiles to water")

	# Restore the developer's real world-memory file.
	if _memory_backup != "":
		var rf := FileAccess.open(SaveManager.WORLD_MEMORY_PATH, FileAccess.WRITE)
		rf.store_string(_memory_backup)
		rf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.WORLD_MEMORY_PATH))
	WorldMemory.reset()

	_finish()


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
