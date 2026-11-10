extends SceneTree
## Headless test for the permanent world memory tier (AGENTS.md §11.1):
## SaveManager file I/O semantics, WorldMemory record/persist/replay,
## the restart loop (kill boss / build ford -> fresh world replays
## them), session-vs-memory precedence, and the F8 dev reset path.
##
##   godot --headless --path . -s res://tests/world_memory_test.gd

var _failures := 0
## Isolation: everything in here persists permanent events, so back up
## / clear / restore the developer's real world-memory file.
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_memory_backup = ""
	if FileAccess.file_exists(SaveManager.WORLD_MEMORY_PATH):
		var f := FileAccess.open(SaveManager.WORLD_MEMORY_PATH, FileAccess.READ)
		_memory_backup = f.get_as_text()
		f.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.WORLD_MEMORY_PATH))
	WorldMemory.reset()

	# --- SaveManager tier: fresh, roundtrip, corrupt, version ---
	var fresh: Dictionary = SaveManager.load_world_memory()
	_expect(fresh["ok"] and fresh["events"].is_empty(),
			"missing memory file = fresh world, not an error")
	var sw: Dictionary = SaveManager.save_world_memory({"ford_built": {"row": 12}})
	_expect(sw["ok"], "memory save ok (%s)" % sw.get("error", ""))
	var lw: Dictionary = SaveManager.load_world_memory()
	_expect(lw["ok"] and lw["events"].has("ford_built"),
			"memory roundtrip preserves events")
	var cf := FileAccess.open(SaveManager.WORLD_MEMORY_PATH, FileAccess.WRITE)
	cf.store_string("{ nope")
	cf.close()
	var bad: Dictionary = SaveManager.load_world_memory()
	_expect(not bad["ok"] and bad["error"] == "corrupted world memory",
			"corrupted memory refused safely")
	var vf := FileAccess.open(SaveManager.WORLD_MEMORY_PATH, FileAccess.WRITE)
	vf.store_string(JSON.stringify({"version": 99, "events": {}}))
	vf.close()
	var old: Dictionary = SaveManager.load_world_memory()
	_expect(not old["ok"] and old["error"].begins_with("unsupported version"),
			"unknown memory version refused")

	# --- WorldMemory unit: record, idempotence, capture/apply, reload ---
	WorldMemory.reset()
	WorldMemory.record(WorldMemory.EVENT_FORD, {"row": 12})
	WorldMemory.record(WorldMemory.EVENT_FORD, {"row": 12})
	_expect(WorldMemory.has_event(WorldMemory.EVENT_FORD)
			and WorldMemory.capture().size() == 1, "record is idempotent")
	_expect(WorldMemory.get_event(WorldMemory.EVENT_FORD)["row"] == 12,
			"event payload readable")
	var snap: Dictionary = WorldMemory.capture()
	WorldMemory.reset()
	WorldMemory.apply(snap)
	_expect(WorldMemory.has_event(WorldMemory.EVENT_FORD), "capture/apply restores events")
	WorldMemory.record_and_persist(WorldMemory.EVENT_RUNE)
	WorldMemory.reset()
	_expect(not WorldMemory.has_event(WorldMemory.EVENT_RUNE), "reset forgets in memory")
	WorldMemory.reload_from_disk()
	_expect(WorldMemory.has_event(WorldMemory.EVENT_FORD)
			and WorldMemory.has_event(WorldMemory.EVENT_RUNE),
			"reload_from_disk restores persisted events")

	# --- Restart loop: boss kill -> fresh world remembers ---
	WorldMemory.reset()
	SaveManager.delete_world_memory()
	var world1: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world1)
	await physics_frame
	await physics_frame
	var boss1: Node2D = world1.get_boss()
	_expect(boss1 != null and is_instance_valid(boss1), "fresh run: boss present")
	boss1.call("take_damage", 999.0, Vector2.RIGHT)
	_expect(WorldMemory.has_event(WorldMemory.EVENT_BOSS),
			"boss death persists immediately (crash-safe)")
	_expect(FileAccess.file_exists(SaveManager.WORLD_MEMORY_PATH),
			"memory file written to disk")

	var world2: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world2)
	await physics_frame
	await physics_frame
	_expect(world2.get_boss() == null, "restart: boss stays dead")
	_expect(world2.boss_defeated, "restart: defeat flag replayed")

	# --- Restart loop: ford + rune replay ---
	world2.build_ford()
	_expect(WorldMemory.has_event(WorldMemory.EVENT_FORD)
			and WorldMemory.has_event(WorldMemory.EVENT_RUNE),
			"ford construction persists ford + rune events")
	var world3: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world3)
	await physics_frame
	await physics_frame
	_expect(_water_cells_in_row(world3.get_node("GroundLayer"), 12) == 0,
			"restart: ford rebuilt from memory")
	var rune_state := 0
	for child in world3.get_entity_parent().get_children():
		if child.has_method("try_activate"):
			rune_state = int(child.get("state"))
	_expect(rune_state == 2, "restart: rune replays as ACTIVATED")
	_expect(world3.get_boss() == null, "restart keeps earlier boss event too")

	# --- Precedence: permanent memory beats an older session save ---
	var world4: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world4)
	await physics_frame
	await physics_frame
	world4.restore_state({"boss": {"defeated": false, "alive": true,
			"hp": 90.0, "x": 500.0, "y": 300.0}})
	for i in 5:
		await physics_frame
	_expect(world4.get_boss() == null,
			"session save cannot resurrect a permanently dead boss")

	# --- F8 dev reset: forget everything, world rebuilds pristine ---
	var clear_result: Dictionary = WorldMemory.clear_persisted()
	_expect(clear_result["ok"] and not FileAccess.file_exists(SaveManager.WORLD_MEMORY_PATH),
			"clear_persisted removes the memory file")
	var world5: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world5)
	await physics_frame
	await physics_frame
	_expect(world5.get_boss() != null and is_instance_valid(world5.get_boss()),
			"after reset: boss returns")
	_expect(_water_cells_in_row(world5.get_node("GroundLayer"), 12) > 0,
			"after reset: river flows again")

	for child in root.get_children():
		child.free()
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
