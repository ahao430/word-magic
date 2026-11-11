extends SceneTree
## Headless test for Diablo-style mouse combat: the free arcane bolt
## (LMB/Space) with cooldown and kill math, aim snapping onto enemies,
## and the right-button spell echo (weakened repeat of the last text
## cast: 40 percent cost, half damage, repeatable, never colliding
## with session uniqueness; clamped aim range).
##
##   godot --headless --path . -s res://tests/mouse_combat_test.gd

var _failures := 0
var _cache_backup := ""
var _memory_backup := ""
var _ai_backup := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	_memory_backup = TestIsolation.stash(TestIsolation.MEMORY_PATH)
	_ai_backup = AiConfig.capture_config()
	AiConfig.apply_config({})
	SpellCache.reset()
	WorldMemory.reset()

	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	world.get_entity_parent().add_child(player)
	player.hp = 9999.0  # wandering map slimes must not disturb the run
	await physics_frame
	await physics_frame

	# --- Pure aim helper: snap onto a candidate under the cursor ---
	var aim: Vector2 = player.aim_direction(Vector2(100, 100), Vector2(200, 100),
			[{"pos": Vector2(195, 103), "name": "Slime_x"}])
	_expect(aim.angle_to(Vector2.RIGHT) < 0.05, "aim snaps to an enemy near the cursor")
	var aim_far: Vector2 = player.aim_direction(Vector2(100, 100), Vector2(300, 100),
			[{"pos": Vector2(150, 150), "name": "Slime_x"}])
	_expect(aim_far.angle_to(Vector2.RIGHT) < 0.05, "far enemy does not steal the aim")

	# --- Basic bolt: spawns toward the aim, cooldown gates ---
	_expect(player.try_basic_attack(Vector2.RIGHT), "first bolt fires")
	var bolts := 0
	for child in world.get_entity_parent().get_children():
		if child is Area2D:
			bolts += 1
	_expect(bolts == 1, "one arcane bolt in flight")
	_expect(not player.try_basic_attack(Vector2.RIGHT), "cooldown blocks an immediate second bolt")
	for i in 25:
		await physics_frame
	_expect(player.try_basic_attack(Vector2.RIGHT), "bolt ready again after cooldown")

	# --- Five bolts kill a 30hp slime (6 dmg each, point blank) ---
	var slime: CharacterBody2D = load("res://scenes/enemies/slime.tscn").instantiate()
	slime.position = player.global_position + Vector2(36, 0)
	world.get_entity_parent().add_child(slime)
	await physics_frame
	for i in 5:
		while not player.try_basic_attack(Vector2.RIGHT):
			await physics_frame
		await physics_frame
	for i in 40:
		await physics_frame
		if not is_instance_valid(slime):
			break
	_expect(not is_instance_valid(slime), "basic bolts kill a slime in five hits")

	# --- Echo: cost math, half damage, repeatability ---
	var session := SpellSession.new()
	var r1: Dictionary = await MagicFacade.cast("火球术", player, world, session)
	_expect(r1["ok"], "text cast arms the echo")
	# main.gd arms the echo after a successful cast — mirror that wiring.
	player.last_spell = r1["spell"]
	_expect(player.last_spell.get("display", "") == "火球术", "last_spell stored")
	_expect(player.echo_cost() == 8, "echo costs 40 percent (20 -> 8)")
	var echo: Dictionary = player.make_echo_spell()
	_expect(absf(float(echo["parameters"]["damage"]) - 10.0) < 0.01,
			"echo halves damage (20 -> 10)")
	var mana_before: float = player.mana
	_echo_fire(player, world, player.global_position + Vector2(200, 0))
	_expect(absf(mana_before - player.mana - 8.0) < 0.01, "echo charges its cost")
	# Repeatable: same echo again after its 0.8s cooldown (uniqueness
	# never applies to echoes — that is the point).
	for i in 55:
		await physics_frame
	mana_before = player.mana
	_echo_fire(player, world, player.global_position + Vector2(200, 0))
	_expect(absf(mana_before - player.mana - 8.0) < 0.01, "echo repeats freely")

	# --- Echo with no armed spell / no mana ---
	player.last_spell = {}
	var mana_plain: float = player.mana
	_echo_fire(player, world, player.global_position + Vector2(200, 0))
	_expect(absf(player.mana - mana_plain) < 0.01, "no echo without an armed spell")
	player.last_spell = r1["spell"]
	player.mana = 3.0
	var low: float = player.mana
	_echo_fire(player, world, player.global_position + Vector2(200, 0))
	_expect(absf(player.mana - low) < 0.01, "insufficient mana refuses the echo")
	player.mana = 100.0

	# --- Echo aim clamp: explosion lands at most 220px out ---
	var boom: Dictionary = await MagicFacade.cast("烈焰焚天", player, world, session)
	_expect(boom["ok"], "explosion text cast arms a booming echo")
	player.last_spell = boom["spell"]
	var far_aim: Vector2 = player.global_position + Vector2(500, 0)
	var result: Dictionary = SpellExecutor.execute(player.make_echo_spell(), player, world, far_aim)
	_expect(result["ok"], "echo executes toward the far aim")
	var blast: Node2D = null
	for child in world.get_entity_parent().get_children():
		if child.get_script() == load("res://scripts/effects/blast.gd"):
			blast = child
	_expect(blast != null, "echo blast spawned")
	if blast != null:
		_expect(absf(blast.global_position.distance_to(player.global_position) - 220.0) < 2.0,
				"aim clamps onto the 220px ring (%.0f px)" %
				blast.global_position.distance_to(player.global_position))

	# --- Facing fallback unchanged (no aim point) ---
	var no_aim: Dictionary = SpellExecutor.execute(player.make_echo_spell(), player, world)
	_expect(no_aim["ok"], "echo still fires without an aim point")

	_teardown(world)


func _echo_fire(player: CharacterBody2D, world: Node2D, aim: Vector2) -> void:
	# Mirrors main._try_echo_cast minus HUD toasts.
	if player.last_spell.is_empty() or not player.echo_ready():
		return
	var cost: int = player.echo_cost()
	if not player.try_consume_mana(float(cost)):
		return
	player.consume_echo_cooldown()
	SpellExecutor.execute(player.make_echo_spell(), player, world, aim)


func _teardown(world: Node2D) -> void:
	world.free()
	TestIsolation.unstash(TestIsolation.CACHE_PATH, _cache_backup)
	TestIsolation.unstash(TestIsolation.MEMORY_PATH, _memory_backup)
	AiConfig.apply_config(_ai_backup)
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
