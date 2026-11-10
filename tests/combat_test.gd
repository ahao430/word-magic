extends SceneTree
## Headless combat integration test: fireball kills a slime, contact
## melee hurts the player, and player death respawns fully restored.
##
##   godot --headless --path . -s res://tests/combat_test.gd

var _failures := 0
## Isolation: casts here persist spell-cache entries.
var _cache_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	SpellCache.reset()
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(700, 528)
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	# --- Fireball kills a slime (30 HP, 20 dmg per 火球术: two hits) ---
	var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime.position = player.global_position + Vector2(140, 0)
	world.get_entity_parent().add_child(slime)
	await physics_frame

	# Face right so the projectile flies toward the slime.
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_right")

	var session := SpellSession.new()
	var r1: Dictionary = MagicFacade.cast("火球术", player, world, session)
	_expect(r1["ok"], "first 火球术 cast")
	for i in 45:
		await physics_frame
	_expect(is_instance_valid(slime) and slime.hp <= 10.0,
			"first hit lands (hp %.1f of 30)" % (slime.hp if is_instance_valid(slime) else -1.0))

	# Session uniqueness: 火球术 is spent this adventure, so the killing
	# blow must be a different spell (寒冰箭, 16 dmg >= remaining 10).
	var r2: Dictionary = MagicFacade.cast("寒冰箭", player, world, session)
	_expect(r2["ok"], "寒冰箭 as the killing cast")
	for i in 60:
		await physics_frame
		if not is_instance_valid(slime):
			break
	_expect(not is_instance_valid(slime), "slime dies after two hits")

	# --- Contact melee: an adjacent slime hurts the player ---
	var biter: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	biter.position = player.global_position + Vector2(18, 0)
	world.get_entity_parent().add_child(biter)
	var hp_before: float = player.hp
	for i in 60:
		await physics_frame
	_expect(player.hp < hp_before or not is_instance_valid(player),
			"contact damage applies (hp %.1f -> %.1f)" % [hp_before, player.hp])

	# --- Player death respawns restored at the crossing ---
	# Remove the biter and let the hit-invulnerability window expire so
	# the death blow is not absorbed by it.
	biter.queue_free()
	for i in 55:
		await physics_frame
	player.take_damage(999.0, Vector2.RIGHT)
	await physics_frame
	await physics_frame
	_expect(player.hp == 30.0 and player.mana == 100.0, "death restores hp/mana")
	_expect(player.global_position.distance_to(Vector2(784, 528)) < 1.0,
			"respawn at the crossing (at %s)" % player.global_position)

	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	SpellCache.reset()
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
