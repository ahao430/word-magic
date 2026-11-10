extends SceneTree
## Headless test for the implemented spell shapes: explosion (one-shot
## AoE), field (freeze zone), tornado (gale push), plus the trust
## rules — the player is never hurt by their own blast, unimplemented
## shapes still refund mana, and zones expire on their own.
##
##   godot --headless --path . -s res://tests/shapes_test.gd

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

	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	world.get_entity_parent().add_child(player)
	# Test stamina: survive the wandering map slimes for the whole run.
	player.hp = 9999.0
	await physics_frame
	await physics_frame

	# --- Explosion (烈焰焚天): a slime near the landing point dies ---
	var slime1: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime1.position = player.global_position + Vector2(96 + 20, 0)  # 116px ahead: inside radius 120
	world.get_entity_parent().add_child(slime1)
	await physics_frame
	# Face right, then cast.
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_right")
	var hp_before_blast: float = player.hp
	var r1: Dictionary = MagicFacade.cast("烈焰焚天", player, world, SpellSession.new())
	_expect(r1["ok"], "烈焰焚天 casts (%s)" % r1["reason"])
	for i in 8:
		await physics_frame
	_expect(not is_instance_valid(slime1) or slime1.hp <= 0.0,
			"blast kills a slime near the landing point (hp %s)" %
			(slime1.hp if is_instance_valid(slime1) else "dead"))

	# The caster stands inside their own blast and is untouched.
	_expect(player.hp == hp_before_blast, "player immune to their own explosion")

	# --- Field (冰封千里): freeze + damage ticks ---
	var session := SpellSession.new()
	var slime2: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime2.position = player.global_position + Vector2(60, 0)  # inside radius 140
	slime2.hp = 200.0  # test stamina: survive the full 3s of ticks
	world.get_entity_parent().add_child(slime2)
	await physics_frame
	var hp2: float = slime2.hp
	var r2: Dictionary = MagicFacade.cast("冰封千里", player, world, session)
	_expect(r2["ok"], "冰封千里 casts")
	for i in 40:
		await physics_frame
	_expect(slime2.hp < hp2, "field ticks damage (hp %.0f -> %.0f)" % [hp2, slime2.hp])
	_expect(float(slime2.get("_freeze_timer")) > 0.0, "slime is frozen")
	var frozen_pos: Vector2 = slime2.global_position
	for i in 30:
		await physics_frame
	_expect(slime2.global_position == frozen_pos, "frozen slime does not move")

	# --- Tornado (风卷残云): gale shove + damage ---
	# Wait out the field zone first: its freeze radius (140) covers the
	# tornado's (90), and a frozen slime correctly ignores gusts.
	for i in 130:
		await physics_frame
	var session3 := SpellSession.new()
	var slime3: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime3.position = player.global_position + Vector2(70, 0)
	slime3.hp = 300.0  # test stamina for the full 4s of ticks
	world.get_entity_parent().add_child(slime3)
	await physics_frame
	var hp3: float = slime3.hp
	var dist_before: float = slime3.global_position.distance_to(player.global_position)
	var r3: Dictionary = MagicFacade.cast("风卷残云", player, world, session3)
	_expect(r3["ok"], "风卷残云 casts")
	for i in 90:
		await physics_frame
	_expect(slime3.hp < hp3, "tornado ticks damage (hp %.0f -> %.0f)" % [hp3, slime3.hp])
	var dist_after: float = slime3.global_position.distance_to(player.global_position)
	_expect(dist_after > dist_before + 24.0,
			"tornado shoves the slime away (%.0f -> %.0f px)" % [dist_before, dist_after])

	# --- Zones expire: no zone nodes linger after their duration ---
	for i in 300:
		await physics_frame
	var zones := 0
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("FieldZone") or child.name.begins_with("Blast"):
			zones += 1
	_expect(zones == 0, "zones expire cleanly (%d left)" % zones)

	# --- Unimplemented shape still refunds (shield via raw executor) ---
	var mana_before: float = player.mana
	var fake := {"display": "守护之壁", "element": "nature", "shape": "shield",
			"mechanics": [], "parameters": {"damage": 0.0, "radius": 60.0,
			"speed": 0.0, "duration": 2.0}, "cost": 10}
	var r4: Dictionary = SpellExecutor.execute(fake, player, world)
	_expect(not r4["ok"] and r4["reason"] == "not_unlocked", "shield shape stays not_unlocked")
	_expect(player.mana == mana_before, "no mana charged by the executor itself")

	_finish()


func _finish() -> void:
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	SpellCache.reset()
	WorldMemory.reset()
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
