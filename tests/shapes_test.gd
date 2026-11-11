extends SceneTree
## Headless test for the implemented spell shapes: explosion (one-shot
## AoE), field (freeze zone), tornado (gale push), plus the trust
## rules — the player is never hurt by their own blast, unimplemented
## shapes still refund mana, and zones expire on their own.
##
##   godot --headless --path . -s res://tests/shapes_test.gd

var _ai_backup := {}
var _failures := 0
var _cache_backup := ""
var _memory_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_ai_backup = AiConfig.capture_config()
	AiConfig.apply_config({})
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
	var r1: Dictionary = await MagicFacade.cast("烈焰焚天", player, world, SpellSession.new())
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
	var r2: Dictionary = await MagicFacade.cast("冰封千里", player, world, session)
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
	var r3: Dictionary = await MagicFacade.cast("风卷残云", player, world, session3)
	_expect(r3["ok"], "风卷残云 casts")
	for i in 90:
		await physics_frame
	_expect(slime3.hp < hp3, "tornado ticks damage (hp %.0f -> %.0f)" % [hp3, slime3.hp])
	var dist_after: float = slime3.global_position.distance_to(player.global_position)
	_expect(dist_after > dist_before + 24.0,
			"tornado shoves the slime away (%.0f -> %.0f px)" % [dist_before, dist_after])

	# --- Beam (烈光贯日): hits along the ray, misses beside it ---
	# Let the tornado field expire first: its 90px reach covers every
	# later placement and its ticks would pollute these assertions.
	for i in 200:
		await physics_frame
	var session4 := SpellSession.new()
	player.mana = 100.0
	var slime4: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime4.position = player.global_position + Vector2(120, 0)  # on the ray (length 160)
	slime4.hp = 200.0
	world.get_entity_parent().add_child(slime4)
	await physics_frame
	var hp4: float = slime4.hp
	var r5: Dictionary = await MagicFacade.cast("烈光贯日", player, world, session4)
	_expect(r5["ok"], "烈光贯日 casts (%s)" % r5["reason"])
	for i in 50:
		await physics_frame
	_expect(slime4.hp < hp4, "beam burns the slime on the ray (hp %.0f -> %.0f)" % [hp4, slime4.hp])
	var off_ray: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	off_ray.position = player.global_position + Vector2(120, 90)  # beside the 24px ray
	off_ray.hp = 200.0
	world.get_entity_parent().add_child(off_ray)
	await physics_frame
	var off_hp: float = off_ray.hp
	var r6: Dictionary = await MagicFacade.cast("烈光贯日", player, world, session4)
	_expect(not r6["ok"] and r6["reason"].begins_with("duplicate"),
			"beam is spent for this session")
	_expect(off_ray.hp == off_hp, "slime beside the ray is untouched")

	# --- Area (大地脉动): centered burst with knockback ---
	player.mana = 100.0
	var session5 := SpellSession.new()
	var slime5: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime5.position = player.global_position + Vector2(60, 0)
	slime5.hp = 200.0
	world.get_entity_parent().add_child(slime5)
	await physics_frame
	var hp5: float = slime5.hp
	var dist5: float = slime5.global_position.distance_to(player.global_position)
	var r7: Dictionary = await MagicFacade.cast("大地脉动", player, world, session5)
	_expect(r7["ok"], "大地脉动 casts")
	for i in 20:
		await physics_frame
	_expect(slime5.hp < hp5, "area burst hurts the near slime")
	_expect(slime5.global_position.distance_to(player.global_position) > dist5 + 4.0,
			"area burst knocks the slime back")

	# --- Shield (守护之壁): mitigation for the duration ---
	# Clear every stray enemy: their bites arm the player's invuln
	# window and would swallow the damage probe below.
	for child in world.get_entity_parent().get_children():
		if child is CharacterBody2D and child != player:
			child.free()
	for i in 55:
		await physics_frame
	player.mana = 100.0
	var session6 := SpellSession.new()
	var r8: Dictionary = await MagicFacade.cast("守护之壁", player, world, session6)
	_expect(r8["ok"], "守护之壁 casts")
	_expect(float(player.get("shield_timer")) > 0.0, "shield timer armed")
	var hp_shield: float = player.hp
	player.take_damage(10.0, Vector2.RIGHT)
	_expect(absf(player.hp - (hp_shield - 4.0)) < 0.01,
			"shield cuts damage to 40%% (10 -> %.1f)" % (hp_shield - player.hp))
	# Expire the shield, let the i-frames from the last probe lapse,
	# then a hit lands at full force.
	player.set("shield_timer", 0.0)
	for i in 55:
		await physics_frame
	var hp_plain: float = player.hp
	player.take_damage(10.0, Vector2.RIGHT)
	_expect(absf(player.hp - (hp_plain - 10.0)) < 0.01, "after expiry damage is full")

	# --- Summon (唤灵术): orbiting spirit zaps the nearest enemy ---
	player.mana = 100.0
	var session7 := SpellSession.new()
	var slime6: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime6.position = player.global_position + Vector2(70, 0)
	slime6.hp = 200.0
	world.get_entity_parent().add_child(slime6)
	await physics_frame
	var hp6: float = slime6.hp
	var r9: Dictionary = await MagicFacade.cast("唤灵术", player, world, session7)
	_expect(r9["ok"], "唤灵术 casts")
	var spirit: Node2D = null
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("Summon"):
			spirit = child
	_expect(spirit != null, "spirit node spawned")
	for i in 70:
		await physics_frame
	_expect(slime6.hp < hp6, "spirit zaps the nearest enemy (hp %.0f -> %.0f)" % [hp6, slime6.hp])
	for i in 200:
		await physics_frame
	var spirits := 0
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("Summon"):
			spirits += 1
	_expect(spirits == 0, "spirit dissolves after its duration")

	# --- Zones expire: no zone nodes linger after their duration ---
	for i in 300:
		await physics_frame
	var zones := 0
	for child in world.get_entity_parent().get_children():
		if child.name.begins_with("FieldZone") or child.name.begins_with("Blast"):
			zones += 1
	_expect(zones == 0, "zones expire cleanly (%d left)" % zones)

	# --- Executor fallback: an unknown shape stays not_unlocked ---
	var mana_before: float = player.mana
	var fake := {"display": "梦中咒", "element": "nature", "shape": "dream",
			"mechanics": [], "parameters": {"damage": 0.0, "radius": 60.0,
			"speed": 0.0, "duration": 2.0}, "cost": 10}
	var r4: Dictionary = SpellExecutor.execute(fake, player, world)
	_expect(not r4["ok"] and r4["reason"] == "not_unlocked", "unknown shape stays not_unlocked")
	_expect(player.mana == mana_before, "no mana charged by the executor itself")

	AiConfig.apply_config(_ai_backup)
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
