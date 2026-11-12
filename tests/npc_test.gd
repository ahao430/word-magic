extends SceneTree
## Headless test for the first NPC round: the Forest Keeper's
## world-aware dialogue lines (pure), the code-built dialogue box state
## machine (open/advance/Esc-close), keeper placement + interact
## payload in the world, and the full main-scene E-routing end to end
## (dialogue beats pause while open).

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	SpellCache.reset()
	WorldMemory.reset()
	Weather.reset()

	# --- Pure line builder: the keeper remembers the world ---
	var keeper_script: GDScript = load("res://scripts/world/keeper.gd")
	var fresh: Array = keeper_script.build_lines({})
	_expect(fresh.size() == 4 and fresh[1].contains("沉睡") and fresh[2].contains("石门"),
			"fresh world: boss sleeping, wetland unexplored (%d lines)" % fresh.size())
	var boss_gone: Array = keeper_script.build_lines({"boss_dead": true})
	_expect(boss_gone[1].contains("倒下"), "boss defeat changes the story")
	var found: Array = keeper_script.build_lines({"wetland_found": true})
	_expect(found[2].contains("灵泉"), "wetland discovery changes the story")
	var elite_gone: Array = keeper_script.build_lines({"wetland_found": true, "elite_dead": true})
	_expect(elite_gone.size() == 5 and elite_gone[3].contains("深沼"),
			"elite defeat adds a line only when the wetland is known")

	# --- Dialogue box state machine ---
	var box: PanelContainer = load("res://scripts/ui/dialogue_box.gd").new()
	root.add_child(box)
	await physics_frame
	_expect(not box.visible, "box starts hidden")
	box.open("守林人", ["一", "二", "三"])
	_expect(box.visible, "box opens")
	var closed_count := {"n": 0}
	box.closed.connect(func() -> void: closed_count["n"] = int(closed_count["n"]) + 1)
	_expect(box.advance() and box.advance() and not box.advance(),
			"advance walks pages then closes")
	_expect(not box.visible and int(closed_count["n"]) == 1, "closed signal fired once")
	box.open("守林人", ["一", "二"])
	Input.action_press("pause")
	await process_frame
	Input.action_release("pause")
	await process_frame
	_expect(not box.visible and int(closed_count["n"]) == 2,
			"Esc closes mid-conversation")

	# --- World placement + interact payload ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var keeper: Node2D = world.get_entity_parent().get_node_or_null("Keeper")
	_expect(keeper != null and keeper.has_method("interact"),
			"the keeper stands by the gate")
	var talk: Dictionary = keeper.call("interact", null)
	_expect(bool(talk["ok"]) and talk["dialogue"]["speaker"] == "守林人"
			and (talk["dialogue"]["lines"] as Array).size() == 4,
			"interact returns speaker + world-aware lines")

	# --- End to end: main routes E, dialogue beats pause ---
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	await physics_frame
	var player: CharacterBody2D = null
	for child in main.get_node("World").get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player = child
			break
	var keeper2: Node2D = main.get_node("World").get_entity_parent().get_node_or_null("Keeper")
	player.global_position = keeper2.global_position + Vector2(0, -20)
	await physics_frame
	main.call("_handle_interact")
	await physics_frame
	var hbox: PanelContainer = main.get_node("HUD/DialogueBox")
	_expect(hbox != null and hbox.visible, "E opens the dialogue box")
	var pause_panel: PanelContainer = main.get_node("HUD/PausePanel")
	Input.action_press("pause")
	await process_frame
	Input.action_release("pause")
	await process_frame
	_expect(not hbox.visible and not pause_panel.visible,
			"Esc closes the dialogue without pausing")
	main.call("_handle_interact")
	await physics_frame
	_expect(hbox.visible, "re-talking reopens the box")
	# Walk until closed; extra presses beyond the last page would start
	# a fresh conversation (the player is still standing there).
	var advances := 0
	while hbox.visible and advances < 10:
		main.call("_handle_interact")
		advances += 1
	_expect(not hbox.visible and advances >= 3,
			"E walks every page and closes (%d advances)" % advances)
	main.free()
	world.free()
	await physics_frame

	_teardown()


func _teardown() -> void:
	Weather.reset()
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	SpellCache.reset()
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
