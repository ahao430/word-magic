extends SceneTree
## Headless test for the spellbook codex UI: scroll container layout,
## rows appear per cast, live filter (name / element, raw or localized),
## empty-state hint, and rebuild after a session load.
##
##   godot --headless --path . -s res://tests/spellbook_test.gd

var _failures := 0
## World memory isolation: the main scene is real; nothing here records
## permanent events, but keep the run hermetic anyway.
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

	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var book: PanelContainer = main.get_node("HUD/Spellbook")
	var list: VBoxContainer = main.get_node("HUD/Spellbook/Margin/Rows/ListScroll/List")
	var scroll: ScrollContainer = main.get_node("HUD/Spellbook/Margin/Rows/ListScroll")
	var filter: LineEdit = main.get_node("HUD/Spellbook/Margin/Rows/FilterInput")
	var empty_hint: Label = main.get_node("HUD/Spellbook/Margin/Rows/EmptyHint")

	# --- Layout: list lives inside a scroll container, filter present ---
	_expect(not book.visible, "spellbook starts hidden")
	_expect(scroll != null and list.get_parent() == scroll,
			"codex list is wrapped in a scroll container")
	_expect(filter != null and filter.placeholder_text != "", "filter input present")

	# --- Empty state before any cast ---
	_expect(empty_hint.visible and list.get_child_count() == 0,
			"empty hint shown before the first spell")

	# --- Two casts -> two rows, hint clears ---
	main.call("_on_cast_submitted", "火球术")
	main.call("_on_cast_submitted", "寒冰箭")
	await physics_frame
	_expect(list.get_child_count() == 2, "two codex rows after two casts")
	_expect(not empty_hint.visible, "empty hint clears after learning")

	# --- Filter: localized element narrows to one row ---
	filter.text = "火"
	main.call("_apply_codex_filter")
	var visible_fire := 0
	for row in list.get_children():
		if row.visible:
			visible_fire += 1
	_expect(visible_fire == 1, "filter 火 shows exactly one row")

	# --- Raw element string also matches ---
	filter.text = "ice"
	main.call("_apply_codex_filter")
	var visible_ice := 0
	for row in list.get_children():
		if row.visible:
			visible_ice += 1
	_expect(visible_ice == 1, "filter ice (raw element) matches 寒冰箭")

	# --- No match hides everything without destroying rows ---
	filter.text = "zzz"
	main.call("_apply_codex_filter")
	var visible_none := 0
	for row in list.get_children():
		if row.visible:
			visible_none += 1
	_expect(visible_none == 0 and list.get_child_count() == 2,
			"no-match hides rows but keeps them")

	# --- Clearing the filter restores all rows ---
	filter.text = ""
	main.call("_apply_codex_filter")
	var visible_all := 0
	for row in list.get_children():
		if row.visible:
			visible_all += 1
	_expect(visible_all == 2, "cleared filter shows everything again")

	# --- Rebuild (the session-load path) keeps rows + reapplies filter ---
	filter.text = "火"
	main.call("_rebuild_codex_ui")
	var visible_after := 0
	for row in list.get_children():
		if row.visible:
			visible_after += 1
	_expect(visible_after == 1 and list.get_child_count() == 2,
			"rebuild restores rows and re-applies the filter")

	for child in root.get_children():
		child.free()
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
