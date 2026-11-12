extends SceneTree
## Headless test for the NPC + quest round: the Forest Keeper's
## world-aware dialogue lines (pure), the first quest (「取回沼泽之心」:
## E-on-final-page commits, Esc postpones), the dialogue box state
## machine, keeper placement in the world, and the full main-scene
## E-routing end to end (dialogue beats pause; quest commits only on
## E; blessing replays from world memory).

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
	var fresh: Dictionary = keeper_script.build_lines({})
	_expect((fresh["lines"] as Array).size() == 5
			and fresh["lines"][1].contains("沉睡")
			and fresh["lines"][2].contains("石门")
			and fresh["action"] == keeper_script.ACTION_ACCEPT,
			"fresh world: intro + quest offer with accept action")
	var boss_gone: Dictionary = keeper_script.build_lines({"boss_dead": true})
	_expect(boss_gone["lines"][1].contains("倒下"), "boss defeat changes the story")
	var taken: Dictionary = keeper_script.build_lines({"quest_taken": true})
	_expect(not taken.has("action") and taken["lines"][3].contains("委托还挂着"),
			"active quest: progress line, no action")
	var ready: Dictionary = keeper_script.build_lines({"quest_taken": true, "elite_dead": true})
	_expect(ready["action"] == keeper_script.ACTION_TURN_IN
			and ready["lines"][3].contains("E 交付"),
			"elite dead + quest active: turn-in page")
	var done: Dictionary = keeper_script.build_lines({"quest_done": true})
	_expect(done["lines"][3].contains("清晰多了")
			and done.get("action", "") == keeper_script.ACTION_EXPEDITION,
			"quest done: thanks line, then the expedition offer")
	var refused: Dictionary = keeper_script.build_lines({"elite_dead": true})
	_expect(not refused.has("action") and refused["lines"][3].contains("可惜了"),
			"elite dead without the quest: a regret line, no action")

	# --- Dialogue box state machine ---
	var box: PanelContainer = load("res://scripts/ui/dialogue_box.gd").new()
	root.add_child(box)
	await physics_frame
	_expect(not box.visible, "box starts hidden")
	box.open("守林人", ["一", "二", "三"])
	_expect(box.visible, "box opens")
	var closes := {"advance": 0, "esc": 0}
	box.closed.connect(func(via_advance: bool) -> void:
		closes["advance"] = int(closes["advance"]) + (1 if via_advance else 0)
		closes["esc"] = int(closes["esc"]) + (0 if via_advance else 1))
	_expect(box.advance() and box.advance() and not box.advance(),
			"advance walks pages then closes")
	_expect(int(closes["advance"]) == 1 and not box.visible, "E-close reports via_advance")
	box.open("守林人", ["一", "二"])
	Input.action_press("pause")
	await process_frame
	Input.action_release("pause")
	await process_frame
	_expect(not box.visible and int(closes["esc"]) == 1,
			"Esc closes mid-conversation as a postpone")

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
			and (talk["dialogue"]["lines"] as Array).size() == 5
			and talk["pending_action"] == keeper_script.ACTION_ACCEPT,
			"interact returns world-aware lines + the quest offer")

	# --- confirm_action: accept, turn-in, guards ---
	var accept: Dictionary = keeper.call("confirm_action", null, keeper_script.ACTION_ACCEPT)
	_expect(bool(accept["ok"]) and WorldMemory.has_event(WorldMemory.EVENT_QUEST_TAKEN),
			"E-confirmed accept records the quest")
	_expect(not keeper.call("confirm_action", null, keeper_script.ACTION_ACCEPT)["ok"],
			"double-accept refused")
	_expect(not keeper.call("confirm_action", null, keeper_script.ACTION_TURN_IN)["ok"],
			"turn-in refused before the elite falls")
	WorldMemory.record_and_persist(WorldMemory.EVENT_ELITE)
	var donor: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(donor)
	await physics_frame
	var turned: Dictionary = keeper.call("confirm_action", donor, keeper_script.ACTION_TURN_IN)
	_expect(bool(turned["ok"]) and WorldMemory.has_event(WorldMemory.EVENT_QUEST_DONE)
			and absf(float(donor.get("mana_regen")) - 2.5) < 0.001,
			"turn-in blesses the regen 2.0 -> 2.5 (%.2f)" % float(donor.get("mana_regen")))
	donor.free()
	# --- The taught idiom: locked, then unlocked by the quest ---
	WorldMemory.reset()
	_expect(LocalSpellRegistry.lookup("激流贯射").is_empty(),
			"the taught spell is unknown before the quest")
	WorldMemory.record_and_persist(WorldMemory.EVENT_QUEST_DONE)
	var taught: Dictionary = LocalSpellRegistry.lookup("激流贯射")
	_expect(not taught.is_empty() and taught["element"] == "water"
			and SpellBalance.compute_cost(SpellValidator.validate(taught)["spell"]) == 32,
			"quest completion unlocks 激流贯射 (cost 32)")
	var ready2: Dictionary = keeper_script.build_lines(
			{"quest_taken": true, "elite_dead": true})
	_expect(ready2["lines"][3].contains("激流贯射"),
			"the turn-in page teaches the incantation")

	# --- End to end: main routes E, dialogue beats pause, quest commits ---
	WorldMemory.reset()
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
			"Esc closes the dialogue without pausing or committing")
	_expect(not WorldMemory.has_event(WorldMemory.EVENT_QUEST_TAKEN),
			"Esc on the offer page postpones the quest")
	main.call("_handle_interact")
	await physics_frame
	_expect(hbox.visible, "re-talking reopens the box")
	var steps := 0
	while hbox.visible and steps < 10:
		main.call("_handle_interact")
		steps += 1
	_expect(not hbox.visible and steps >= 4,
			"E walks every page and closes (%d advances)" % steps)
	_expect(WorldMemory.has_event(WorldMemory.EVENT_QUEST_TAKEN),
			"E-confirming the final page accepts the quest")
	main.free()
	world.free()
	await physics_frame

	# --- Blessing replays from world memory on a fresh main ---
	WorldMemory.reset()
	WorldMemory.record_and_persist(WorldMemory.EVENT_QUEST_DONE)
	var main2: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main2)
	await physics_frame
	await physics_frame
	var player2: CharacterBody2D = null
	for child in main2.get_node("World").get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player2 = child
			break
	_expect(absf(float(player2.get("mana_regen")) - 2.5) < 0.001,
			"keeper's blessing replays from world memory")
	main2.free()
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
