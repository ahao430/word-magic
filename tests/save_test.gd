extends SceneTree
## Headless test for the session save system: SaveManager roundtrip +
## corruption handling, and a full save -> fresh world -> restore flow
## (ford, rune, dead slimes, spell session, player state).
##
##   godot --headless --path . -s res://tests/save_test.gd

const SLOT := "slot_test"

var _ai_backup := {}
var _failures := 0
## World memory isolation: the rune activation in here persists a
## permanent event — back up / clear / restore the real file.
var _memory_backup := ""
var _cache_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_ai_backup = AiConfig.capture_config()
	AiConfig.apply_config({})
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	WorldMemory.reset()
	SpellCache.reset()
	# --- SaveManager unit: roundtrip ---
	var sample := {"a": 1, "b": "文字", "nested": {"c": [1, 2, 3]}}
	var s1: Dictionary = SaveManager.save_game(sample, SLOT)
	_expect(s1["ok"], "save writes (%s)" % s1.get("error", ""))
	var l1: Dictionary = SaveManager.load_game(SLOT)
	# Compare semantically: JSON numbers come back as floats, so str()
	# comparison of 1 vs 1.0 would false-fail.
	_expect(l1["ok"] and l1["state"]["b"] == "文字" and l1["state"]["a"] == 1
			and l1["state"]["nested"]["c"].size() == 3, "roundtrip preserves data")

	# --- Corruption handling ---
	var path := SaveManager.slot_path(SLOT)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ not json !!!")
	file.close()
	var l2: Dictionary = SaveManager.load_game(SLOT)
	_expect(not l2["ok"] and l2["error"] == "corrupted save", "corrupted file refused safely")
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string(JSON.stringify({"version": 999, "state": {}}))
	bad.close()
	var l3: Dictionary = SaveManager.load_game(SLOT)
	_expect(not l3["ok"] and l3["error"].begins_with("unsupported version"),
			"unknown version refused (%s)" % l3["error"])

	# --- Integration: play, save, rebuild, restore ---
	var world1: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world1)
	var player1: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player1.position = Vector2(500, 300)
	world1.get_entity_parent().add_child(player1)
	await physics_frame
	await physics_frame

	var session1 := SpellSession.new()
	var cast1: Dictionary = await MagicFacade.cast("火球术", player1, world1, session1)
	_expect(cast1["ok"], "world1: 火球术 cast")
	player1.take_damage(10.0, Vector2.RIGHT)
	await physics_frame

	# Kill one slime by name (damage path, not projectiles).
	var victim: CharacterBody2D = null
	for child in world1.get_entity_parent().get_children():
		if child is CharacterBody2D and child.name.begins_with("Slime_"):
			victim = child
			break
	_expect(victim != null, "world1: a slime exists")
	var slime_count_before := _slime_count(world1)
	victim.take_damage(999.0, Vector2.RIGHT)
	for i in 30:
		await physics_frame

	# Awaken the rune with an ice spell cast right beside it.
	var stone: Node2D = null
	for child in world1.get_entity_parent().get_children():
		if child.has_method("try_activate"):
			stone = child
	var ice: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup("寒冰箭"))["spell"]
	var react: String = world1.on_spell_cast(ice, stone.position + Vector2(20, 0))
	_expect(react != "", "world1: rune reacts (%s)" % react)
	for i in 50:
		await physics_frame

	# Compose + save exactly like main.gd does.
	var state := {
		"player": {"x": player1.global_position.x, "y": player1.global_position.y,
				"hp": player1.hp, "mana": player1.mana},
		"session": session1.capture_state(),
		"world": world1.capture_state(),
	}
	var save_result: Dictionary = SaveManager.save_game(state, SLOT)
	_expect(save_result["ok"], "integration save ok")

	# Fresh world + player + session (a "restart").
	var world2: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world2)
	var player2: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	world2.get_entity_parent().add_child(player2)
	var session2 := SpellSession.new()
	await physics_frame
	await physics_frame

	var loaded: Dictionary = SaveManager.load_game(SLOT)
	_expect(loaded["ok"], "integration load ok")
	var ls: Dictionary = loaded["state"]
	var p2: Dictionary = ls["player"]
	player2.global_position = Vector2(p2["x"], p2["y"])
	player2.hp = p2["hp"]
	player2.mana = p2["mana"]
	session2.restore_state(ls["session"])
	world2.restore_state(ls["world"])

	# Player tier — assert immediately, before further frames tick and
	# mana regen can drift the numbers (compared vs SAVED values, not
	# the still-simulating world1 player).
	_expect(player2.hp == p2["hp"] and absf(player2.mana - float(p2["mana"])) < 0.01,
			"player hp/mana restored (%.0f/%.0f)" % [player2.hp, player2.mana])
	_expect(player2.global_position.distance_to(player1.global_position) < 0.5,
			"player position restored")

	await physics_frame
	await physics_frame

	# World tier: ford walkable, rune awake, one slime still dead.
	_expect(_water_cells_in_row(world2.get_node("GroundLayer"), 12) == 0, "ford rebuilt on load")
	var stone2: Node2D = null
	for child in world2.get_entity_parent().get_children():
		if child.has_method("try_activate"):
			stone2 = child
	_expect(stone2 != null and stone2.state == 2, "rune restored as ACTIVATED")
	_expect(_slime_count(world2) == slime_count_before - 1,
			"dead slime stays dead (%d of %d)" % [_slime_count(world2), slime_count_before])

	# Session tier: uniqueness and codex survive the restart.
	_expect(session2.codex.size() == 1, "codex restored (1 entry)")
	var recast: Dictionary = await MagicFacade.cast("火球术", player2, world2, session2)
	_expect(not recast["ok"] and recast["reason"].begins_with("duplicate_"),
			"used spells stay spent after reload (%s)" % recast["reason"])

	# Restore the developer's real world state files.
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	WorldMemory.reset()
	SpellCache.reset()

	AiConfig.apply_config(_ai_backup)
	_finish()


func _slime_count(world: Node) -> int:
	var count := 0
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and child.name.begins_with("Slime_") and not child.is_queued_for_deletion():
			count += 1
	return count


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
