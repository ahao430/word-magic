extends SceneTree
## Headless test for the journey page (X10): the counter layer of the
## world memory (bump math, persistence round-trip, legacy-file
## compatibility), the five live data sources (slime/fly kills, casts,
## deaths, expedition runs), and the pause-panel journey page itself
## (opens with stats + timeline rows, Esc closes before pause resumes).

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	SpellCache.reset()
	WorldMemory.reset()
	Weather.reset()

	# --- Counter math + defaults ---
	WorldMemory.bump_counter("slain_slimes", 3)
	WorldMemory.bump_counter("slain_flies", 5)
	_expect(WorldMemory.counter("slain_slimes") == 3
			and WorldMemory.counter("slain_flies") == 5
			and WorldMemory.counter("unknown_key") == 0,
			"bump math and unknown-key default")

	# --- Persistence round-trip ---
	WorldMemory.reload_from_disk()
	_expect(WorldMemory.counter("slain_slimes") == 3
			and WorldMemory.counter("slain_flies") == 5,
			"counters survive a disk reload")

	# --- Legacy file (no counters key) loads clean ---
	var mf := FileAccess.open("user://world_memory.json", FileAccess.WRITE)
	mf.store_string(JSON.stringify({"version": 1,
			"events": {"boss_slime_defeated": {}}}))
	mf.close()
	WorldMemory.reload_from_disk()
	_expect(WorldMemory.has_event(WorldMemory.EVENT_BOSS)
			and WorldMemory.counter("slain_slimes") == 0,
			"legacy file loads with events and zero counters")
	WorldMemory.reset()

	# --- Live data sources ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.hp = 9999.0
	player.position = Vector2(500, 300)
	world.get_entity_parent().add_child(player)
	await physics_frame

	# Slime death bumps slain_slimes (scatter connects died -> handler).
	var slime: CharacterBody2D = first_enemy_named(world, "Slime_")
	_expect(slime != null, "a forest slime exists")
	var n0: int = WorldMemory.counter("slain_slimes")
	slime.call("take_damage", 999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("slain_slimes") == n0 + 1,
			"slaying a forest slime bumps the counter")

	# Fly death bumps slain_flies.
	var fly: CharacterBody2D = first_enemy_named(world, "SwampFly_")
	_expect(fly != null, "a swamp fly exists")
	var f0: int = WorldMemory.counter("slain_flies")
	fly.call("take_damage", 999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("slain_flies") == f0 + 1,
			"dropping a fly bumps its counter")

	# Successful casts bump casts_ok (main's cast path).
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	world.free()
	await physics_frame
	var player2: CharacterBody2D = null
	for child in main.get_node("World").get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player2 = child
			break
	var casts0: int = WorldMemory.counter("casts_ok")
	# The counter lives in main's cast path — drive the UI entry, not
	# the facade directly (a facade cast bypasses main by design).
	main.call("_on_cast_submitted", "火球术")
	await physics_frame
	await physics_frame
	_expect(WorldMemory.counter("casts_ok") == casts0 + 1,
			"a successful cast via main bumps casts_ok")
	main.get_node("HUD/CastInput").text = "完全未知的词"
	main.call("_on_cast_submitted", "完全未知的词")
	await physics_frame
	_expect(WorldMemory.counter("casts_ok") == casts0 + 1,
			"a failed cast leaves the counter alone")

	# Player death bumps deaths (respawn counter).
	var d0: int = WorldMemory.counter("deaths")
	player2.hp = 1.0
	player2.call("take_damage", 50.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("deaths") == d0 + 1
			and absf(float(player2.get("hp")) - float(player2.get("hp_max"))) < 0.01,
			"dying bumps deaths and respawns topped-up")

	# Expedition runs via the keeper flow.
	var keeper: Node2D = main.get_node("World").get_entity_parent().get_node_or_null("Keeper")
	WorldMemory.record_and_persist(WorldMemory.EVENT_QUEST_DONE)
	keeper.call("confirm_action", player2, "accept_expedition")
	var echo: CharacterBody2D = main.get_node("World").get_entity_parent().get_node_or_null("SlimeEliteEcho")
	var runs0: int = WorldMemory.counter("expedition_runs")
	if echo != null:
		echo.call("take_damage", 999.0, Vector2.RIGHT)
		await physics_frame
	_expect(WorldMemory.counter("expedition_runs") == runs0 + 1,
			"an expedition settle bumps expedition_runs")

	# --- The journey page: open renders stats + timeline; Esc closes ---
	var pause_panel: PanelContainer = main.get_node("HUD/PausePanel")
	var journey: PanelContainer = main.get_node("HUD/JourneyPanel")
	# A timeline event beyond the quest (expedition's event id is not
	# itself a timeline row).
	WorldMemory.record_and_persist(WorldMemory.EVENT_BOSS)
	_expect(journey != null and not journey.visible, "journey page starts hidden")
	var rows: VBoxContainer = journey.get_node("Margin/Rows")
	var stats_rows: VBoxContainer = rows.get_child(1)
	journey.call("open")
	_expect(journey.visible and stats_rows.get_child_count() >= 4,
			"opening renders the counter rows (%d)" % stats_rows.get_child_count())
	var timeline_rows: VBoxContainer = rows.get_child(4)
	_expect(timeline_rows.get_child_count() >= 2,
			"the timeline lists recorded events (%d)" % timeline_rows.get_child_count())
	Input.action_press("pause")
	await process_frame
	Input.action_release("pause")
	await process_frame
	_expect(not journey.visible, "Esc closes the journey page")
	Input.action_press("pause")
	await process_frame
	Input.action_release("pause")
	await process_frame
	_expect(pause_panel.visible, "Esc again shows the pause menu")
	main.free()
	await physics_frame

	_teardown()


func first_enemy_named(world: Node2D, prefix: String) -> CharacterBody2D:
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and str(child.name).begins_with(prefix):
			return child
	return null


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
