extends SceneTree
## Headless test for the scene flow: title screen states (continue
## button gating on the session save), the pending-load handoff into
## main, and the pause overlay (Esc toggles, world freezes, buttons
## exist).
##
##   godot --headless --path . -s res://tests/flow_test.gd

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _slot_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The -s root script compiles before autoloads register, so resolve
	# GameManager through the tree instead of the global name.
	var gm: Node = root.get_node("/root/GameManager")
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_slot_backup = TestIsolation.stash(SaveManager.slot_path("slot_01"))
	SpellCache.reset()
	WorldMemory.reset()

	# --- Title: fresh machine (no save) disables "continue" ---
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await physics_frame
	_expect(int(gm.state) == 1, "title sets MENU state")
	var continue_btn: Button = title.get_node("Margin/Rows/ContinueButton")
	_expect(continue_btn.disabled, "continue disabled without a save")
	title.free()

	# --- A session save lights the continue button up ---
	var save_result: Dictionary = SaveManager.save_game(
			{"player": {"x": 640.0, "y": 400.0, "hp": 22.0, "mana": 55.0},
			"session": {}, "world": {}}, "slot_01")
	_expect(save_result["ok"], "staged a session save")
	title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await physics_frame
	continue_btn = title.get_node("Margin/Rows/ContinueButton")
	_expect(not continue_btn.disabled, "continue enabled with a save")
	title.free()

	# --- Pending-load handoff: main._ready consumes the flag ---
	gm.pending_load_session = true
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout
	_expect(not gm.pending_load_session, "main consumed the pending-load flag")
	var player: CharacterBody2D = main.get_node("World").get_entity_parent().get_node("Player")
	for child in main.get_node("World").get_entity_parent().get_children():
		if child.name.begins_with("Slime_"):
			child.free()
	await physics_frame
	_expect(player != null and player.global_position.distance_to(Vector2(640, 400)) < 1.0,
			"session restored onto the player (at %s)" % player.global_position)
	# Mana regen runs during the 0.4s settle wait, so compare with a
	# regen allowance; hp has no regen and matches exactly.
	_expect(float(player.hp) == 22.0 and absf(float(player.mana) - 55.0) < 1.5,
			"hp/mana restored from the save (hp %.0f mana %.1f)" % [player.hp, player.mana])

	# --- Pause overlay: Esc shows it, world freezes, Esc resumes ---
	var panel: PanelContainer = main.get_node("HUD/PausePanel")
	_expect(panel != null and not panel.visible, "pause panel starts hidden")
	var pos_before: Vector2 = player.global_position
	Input.action_press("pause")
	await physics_frame
	await physics_frame
	Input.action_release("pause")
	await physics_frame
	_expect(panel.visible and paused, "Esc opens the pause panel and freezes the tree")
	_expect(int(gm.state) == 3, "state flips to PAUSED")

	# While paused the player must not move.
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
	Input.action_release("move_right")
	_expect(player.global_position == pos_before, "frozen player ignores movement input")

	# Esc again resumes through the panel's own ALWAYS-mode _process.
	Input.action_press("pause")
	await physics_frame
	Input.action_release("pause")
	await physics_frame
	_expect(not panel.visible and not paused, "Esc again resumes")
	_expect(int(gm.state) == 2, "state back to PLAYING")

	# --- Buttons exist for resume / restart / title ---
	_expect(panel.get_node("Margin/Rows/ResumeButton") != null
			and panel.get_node("Margin/Rows/RestartButton") != null
			and panel.get_node("Margin/Rows/TitleButton") != null,
			"pause panel has all three actions")

	# Restart path (wired, but invoked directly to keep current_scene sane).
	paused = false

	# Deferred teardown: this coroutine resumes inside a physics tick,
	# and freeing whole scenes mid-flush aborts the engine on Linux
	# (macOS silently tolerates it). (The old bare title.free() here was
	# a silent no-op — that instance was already freed at line 48.)
	main.queue_free()
	paused = false
	await physics_frame
	await physics_frame
	gm.pending_load_session = false
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	TestIsolation.unstash(SaveManager.slot_path("slot_01"), _slot_backup)
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
