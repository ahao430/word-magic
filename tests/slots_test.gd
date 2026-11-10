extends SceneTree
## Headless test for the multi-slot save system: SaveManager slot ops
## (exists/delete/list/meta), the slot chooser panel in both modes,
## in-game F5/F9 wiring through main, and the title handoff into the
## chosen slot.
##
##   godot --headless --path . -s res://tests/slots_test.gd

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _slot_backups := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	for path in TestIsolation.slot_paths():
		_slot_backups[path] = TestIsolation.stash(path)
	SpellCache.reset()
	WorldMemory.reset()

	# --- SaveManager slot ops ---
	_expect(SaveManager.list_slots().is_empty(), "no slots at start")
	SaveManager.save_game({"v": 1}, "slot_01", {"saved_at": "t1", "summary": "s1"})
	SaveManager.save_game({"v": 2}, "slot_03", {"saved_at": "t3", "summary": "s3"})
	var slots: Array[String] = SaveManager.list_slots()
	_expect(slots.size() == 2 and slots[0] == "slot_01" and slots[1] == "slot_03",
			"list_slots reports occupied slots in order")
	_expect(SaveManager.slot_exists("slot_01") and not SaveManager.slot_exists("slot_02"),
			"slot_exists distinguishes slots")
	var loaded: Dictionary = SaveManager.load_game("slot_03")
	_expect(loaded["ok"] and loaded["meta"]["summary"] == "s3",
			"meta roundtrips outside the game state")
	SaveManager.delete_slot("slot_01")
	var after_delete: Array[String] = SaveManager.list_slots()
	_expect(not SaveManager.slot_exists("slot_01") and after_delete.size() == 1
			and after_delete[0] == "slot_03",
			"delete_slot removes exactly one slot")
	SaveManager.delete_slot("slot_01")
	_expect(true, "deleting a missing slot is a harmless no-op")

	# --- Slot panel: both modes ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	var panel: Control = load("res://scenes/ui/slot_panel.tscn").instantiate()
	root.add_child(panel)
	await physics_frame
	_expect(not panel.visible, "slot panel starts hidden")
	panel.open_load_mode()
	_expect(panel.visible, "load mode opens")
	var rows: VBoxContainer = panel.get_node("Panel/Margin/Rows/SlotRows")
	var choose2: Button = rows.get_node("Slot2/ChooseButton")
	_expect(choose2.disabled, "empty slot is disabled in load mode")
	panel._close()
	_expect(not panel.visible, "Esc close works")

	panel.open_save_mode()
	# Standalone panel: nobody owns the signal here, so write through it.
	panel.slot_chosen.connect(func(slot: String) -> void:
		SaveManager.save_game({"via": "panel"}, slot,
				{"saved_at": "panel-time", "summary": "panel test"}))
	_expect(panel.get_node("Panel/Margin/Rows/TitleLabel").text == "保存冒险",
			"save mode title")
	_expect(not choose2.disabled, "save mode allows overwriting empty slots")
	# Save into slot 2 through the panel callback.
	panel._on_choose_pressed(1)
	_expect(SaveManager.slot_exists("slot_02"), "choosing a slot writes the save")
	# Row summary now reflects the new save in load mode.
	panel.open_load_mode()
	var summary2: Label = rows.get_node("Slot2/Info/SummaryLabel")
	_expect(not summary2.text.contains("空槽"), "row card shows the new save meta")
	# Delete through the panel button.
	rows.get_node("Slot2/DeleteButton").pressed.emit()
	_expect(not SaveManager.slot_exists("slot_02"), "delete button clears the slot")
	panel.open_save_mode()

	# --- In-game wiring: F5 -> panel -> slot_chosen -> save ---
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout
	var gplayer: CharacterBody2D = main.get_node("World").get_entity_parent().get_node("Player")
	gplayer.global_position = Vector2(900, 600)
	main._slot_mode = "save"
	main.get_node("HUD/SlotPanel")._on_choose_pressed(1)  # -> slot_02
	_expect(SaveManager.slot_exists("slot_02"), "in-game save lands in slot_02")

	# Move away, then load back through the panel path.
	gplayer.global_position = Vector2(300, 300)
	main._slot_mode = "load"
	main.get_node("HUD/SlotPanel")._on_choose_pressed(1)
	await create_timer(0.3).timeout
	_expect(gplayer.global_position.distance_to(Vector2(900, 600)) < 1.0,
			"in-game load restores the slot (at %s)" % gplayer.global_position)

	# --- Title handoff: continue -> panel -> chosen slot flag ---
	gm_setup()
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await physics_frame
	var tpanel: Control = title.get_node("SlotPanel")
	tpanel.open_load_mode()
	tpanel._on_choose_pressed(1)
	_expect(bool(gm.get("pending_load_session"))
			and str(gm.get("pending_load_slot")) == "slot_02",
			"title hands off the chosen slot")

	title.free()
	main.free()
	panel.free()
	_test_cleanup()
	_finish()


## -s root scripts compile before autoloads: resolve via the tree.
var gm: Node


func gm_setup() -> void:
	gm = root.get_node("/root/GameManager")


func _test_cleanup() -> void:
	paused = false
	if gm != null:
		gm.pending_load_session = false
		gm.pending_load_slot = "slot_01"
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	for path in _slot_backups:
		TestIsolation.unstash(path, _slot_backups[path])
	SpellCache.reset()
	WorldMemory.reset()
	_finish_ready = true


var _finish_ready := false


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
