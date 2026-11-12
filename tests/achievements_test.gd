extends SceneTree
## Headless test for the achievement layer (X11): the pure evaluator
## (counter/event/expedition_best kinds, boundary + unknown ids), the
## poll loop (unlock -> persist -> idempotent re-poll), multi-unlock in
## one poll, and the journey page's achievement rows.

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

	# --- Pure evaluator: all three kinds + boundaries ---
	var snap := {"counters": {"slain_slimes": 1, "slain_flies": 4,
			"casts_ok": 10}, "events": {}, "expedition_best": -1.0}
	var got: Array = Achievements.evaluate(snap, ["first_blood", "fly_sweeper",
			"words_alight", "unbroken", "echo_slayer", "swift_hunter"])
	_expect(got.has("first_blood") and got.has("words_alight")
			and not got.has("fly_sweeper") and not got.has("unbroken")
			and not got.has("echo_slayer") and not got.has("swift_hunter"),
			"counter thresholds judged exactly (%d qualified)" % got.size())
	# expedition_best boundary: exactly 30.0 qualifies, 30.1 does not.
	var fast: Array = Achievements.evaluate({"counters": {}, "events": {},
			"expedition_best": 30.0}, ["swift_hunter"])
	var slow: Array = Achievements.evaluate({"counters": {}, "events": {},
			"expedition_best": 30.1}, ["swift_hunter"])
	_expect(fast.has("swift_hunter") and slow.is_empty(),
			"the 30s record line is inclusive")
	# Event kind + unknown ids pass through harmlessly.
	var ev: Array = Achievements.evaluate({"counters": {}, "events": {
			"boss_slime_defeated": {}}, "expedition_best": -1.0},
			["king_slayer", "no_such_achievement"])
	_expect(ev.has("king_slayer") and not ev.has("no_such_achievement"),
			"event kind matches, unknown ids are ignored")

	# --- Poll loop: unlock, persist, idempotence ---
	WorldMemory.bump_counter("slain_slimes", 1)
	var first: Array = Achievements.poll_new()
	_expect(first.has("first_blood"), "poll returns the fresh unlock")
	_expect(Achievements.unlocked_ids().has("first_blood"),
			"the unlock is stored in the permanent tier")
	var second: Array = Achievements.poll_new()
	_expect(second.is_empty(), "re-polling is idempotent")
	WorldMemory.reload_from_disk()
	_expect(Achievements.unlocked_ids().has("first_blood"),
			"unlocks survive a disk reload")

	# --- Multi-unlock in a single poll ---
	WorldMemory.bump_counter("slain_flies", 5)
	WorldMemory.bump_counter("casts_ok", 10)
	WorldMemory.record_and_persist(WorldMemory.EVENT_REGION)
	var batch: Array = Achievements.poll_new()
	_expect(batch.has("fly_sweeper") and batch.has("words_alight")
			and batch.has("wetland_far") and batch.size() == 3,
			"one poll may unlock several at once (%d)" % batch.size())

	# --- Journey page rows mirror the definitions ---
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await physics_frame
	var journey: PanelContainer = main.get_node("HUD/JourneyPanel")
	journey.call("open")
	var rows: VBoxContainer = journey.get_node("Margin/Rows")
	var achieve_rows: VBoxContainer = rows.get_child(6)
	_expect(achieve_rows.get_child_count() == Achievements.DEFS.size(),
			"journey lists every achievement (%d)" % achieve_rows.get_child_count())
	var first_row: Label = achieve_rows.get_child(0)
	_expect(first_row.text.begins_with("✧"),
			"unlocked achievements shine (row 0: %s)" % first_row.text)
	journey.call("close")
	main.free()
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
