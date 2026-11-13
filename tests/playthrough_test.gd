extends SceneTree
## One-run acceptance for the WHOLE journey (AGENTS §15 / release gate):
## fresh seed → cast the local table → solve the rune → cross the gate →
## drink the spring → fell the elite → deliver the quest → learn the
## taught spell → run the expedition → slay the king → save/load
## round-trip → achievement tally. Any failed step fails the run.

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _slot_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_slot_backup = TestIsolation.stash(SaveManager.slot_path("slot_01"))
	SpellCache.reset()
	WorldMemory.reset()
	Weather.reset()

	# --- 1. Fresh main on a pending seed ---
	var gm: Node = root.get_node("/root/GameManager")
	gm.set("pending_layout_seed", 424242)
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 4:
		await physics_frame
	var world: Node2D = main.get_node("World")
	var player: CharacterBody2D = null
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player = child
			break
	_expect(int(world.layout_seed) == 424242, "seed handoff lands on the first build")
	player.hp = 9999.0
	player.hp_max = 9999.0
	player.mana = 9999.0
	player.mana_max = 9999.0  # the run spends far more than one bar

	# --- 2. The local table casts (registry source, real costs) ---
	var table := ["火球术", "烈焰焚天", "寒冰箭", "冰封千里", "落雷", "风卷残云",
			"烈光贯日", "大地脉动", "守护之壁", "唤灵术", "沼泽缠绕", "激流冲击"]
	var cast_ok := 0
	for spell_name in table:
		main.call("_on_cast_submitted", spell_name)
		await physics_frame
		await physics_frame
		cast_ok += 1 if WorldMemory.counter("casts_ok") > cast_ok else 0
	_expect(cast_ok >= 11, "the local table casts (%d/12)" % cast_ok)

	# --- 3. Rune puzzle → ford ---
	player.global_position = Vector2(13 * 32 + 16, 12 * 32 + 40)
	await physics_frame
	var rune_msg: String = world.on_spell_cast({"element": "ice", "shape": "projectile"},
			player.global_position)
	_expect(rune_msg.contains("苏醒") or rune_msg.contains("水到渠成"),
			"the rune wakes to ice at its stone (%s)" % rune_msg)
	# The ford lands on the rune's 0.6s activation tween, not inline.
	for i in 50:
		await physics_frame
	_expect(world.ford_built and WorldMemory.has_event(WorldMemory.EVENT_FORD),
			"the ford stands and is remembered")

	# --- 4. Cross the gate: discovery + spring + elite ---
	player.global_position = Vector2(50 * 32 + 16, 16 * 32 + 16)
	for i in 50:
		await physics_frame
	_expect(WorldMemory.has_event(WorldMemory.EVENT_REGION),
			"the wetland discovers the player")
	var spring: Node2D = world.get_entity_parent().get_node_or_null("SwampSpring")
	var m0: float = float(player.get("mana_max"))
	spring.call("interact", player)
	_expect(WorldMemory.has_event(WorldMemory.EVENT_SPRING)
			and absf(float(player.get("mana_max")) - (m0 + 10.0)) < 0.01,
			"the spring blesses (+10 max mana)")
	var elite: CharacterBody2D = world.get_entity_parent().get_node_or_null("SlimeElite_58_10")
	elite.call("take_damage", 9999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.has_event(WorldMemory.EVENT_ELITE),
			"the deep-swamp elite falls (swamp heart)")

	# --- 5. Quest delivery → taught spell ---
	var keeper: Node2D = world.get_entity_parent().get_node_or_null("Keeper")
	keeper.call("confirm_action", player, "accept_quest")
	var turn: Dictionary = keeper.call("confirm_action", player, "turn_in_quest")
	_expect(bool(turn["ok"]) and WorldMemory.has_event(WorldMemory.EVENT_QUEST_DONE),
			"the heart is delivered")
	_expect(LocalSpellRegistry.lookup("激流贯射")["element"] == "water",
			"the taught spell unlocks")
	main.call("_on_cast_submitted", "激流贯射")
	await physics_frame
	await physics_frame
	_expect(WorldMemory.counter("casts_ok") >= cast_ok + 1, "the taught spell casts")

	# --- 6. Expedition: accept, squish the echo, settle ---
	keeper.call("confirm_action", player, "accept_expedition")
	var echo: CharacterBody2D = world.get_entity_parent().get_node_or_null("SlimeEliteEcho")
	echo.call("take_damage", 9999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.counter("expedition_runs") == 1
			and WorldMemory.has_event(WorldMemory.EVENT_EXPEDITION),
			"the expedition settles with a record")

	# --- 7. A forest slime for first blood ---
	var minion: CharacterBody2D = null
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and str(child.name).begins_with("Slime_"):
			minion = child
			break
	if minion != null:
		minion.call("take_damage", 9999.0, Vector2.RIGHT)
		await physics_frame
	_expect(WorldMemory.counter("slain_slimes") >= 1, "first blood drawn")

	# --- 8. Slay the king ---
	var boss: CharacterBody2D = world.get_boss()
	boss.call("take_damage", 9999.0, Vector2.RIGHT)
	await physics_frame
	_expect(WorldMemory.has_event(WorldMemory.EVENT_BOSS) and not bool(boss.get("alive")),
			"the Slime King falls")

	# --- 9. Save → load round-trip on a fresh main ---
	main.call("_do_save", "slot_01")
	await physics_frame
	main.queue_free()
	for i in 2:
		await physics_frame
	var main2: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main2)
	for i in 4:
		await physics_frame
	_expect(int(gm.get("pending_layout_seed")) == 0,
			"the seed handoff is one-shot (second build stays legacy)")
	gm.set("pending_load_session", true)
	gm.set("pending_load_slot", "slot_01")
	var main3: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main3)
	# The load branch runs after main's Music-play await chain settles —
	# poll for the restore instead of a fixed timer (robust under load).
	for i in 240:
		await physics_frame
		if int(main3.get_node("World").layout_seed) == 424242:
			break
	var world3: Node2D = main3.get_node("World")
	_expect(int(world3.layout_seed) == 424242, "the save restores its seed")
	_expect(world3.ford_built and world3.boss_defeated,
			"world memory replays: ford stands, king stays dead")
	# main's own poll runs at 0.5s beats; a fast headless run polls few
	# times — settle the queue manually before tallying.
	Achievements.poll_new()
	_expect(Achievements.unlocked_ids().size() >= 6,
			"the journey lights %d achievements" % Achievements.unlocked_ids().size())
	var player3: CharacterBody2D = null
	for child in world3.get_entity_parent().get_children():
		if child is CharacterBody2D and child.name == "Player":
			player3 = child
			break
	# The test inflated mana_max to 9999 pre-save; the replay applies
	# the spring blessing onto the BASE (100) -> 110 on a fresh build.
	_expect(player3 != null and is_instance_valid(player3)
			and float(player3.get("mana_max")) > 100.0,
			"growth replays onto the loaded player (%s)" % [
			player3.get("mana_max") if player3 != null and is_instance_valid(player3) else "gone"])
	main2.queue_free()
	main3.queue_free()
	for i in 2:
		await physics_frame

	print("---- journey summary ----")
	print("achievements: ", Achievements.unlocked_ids())
	print("counters: slain=%d flies=%d casts=%d deaths=%d expeditions=%d"
			% [WorldMemory.counter("slain_slimes"), WorldMemory.counter("slain_flies"),
			WorldMemory.counter("casts_ok"), WorldMemory.counter("deaths"),
			WorldMemory.counter("expedition_runs")])
	print("-------------------------")

	_teardown()


func _teardown() -> void:
	Weather.reset()
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	TestIsolation.unstash(SaveManager.slot_path("slot_01"), _slot_backup)
	SpellCache.reset()
	WorldMemory.reset()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PLAYTHROUGH OK")
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
