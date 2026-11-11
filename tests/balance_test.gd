extends SceneTree
## Headless guard for the balance table (AGENTS.md §7.6):
## - one-shot spell costs are unchanged by the potential-tick pricing;
## - channeled shapes are priced by the ticks their duration allows;
## - every registry spell — and every max-clamped crafted spell — stays
##   under the 2.0 damage-per-mana ceiling;
## - the effect nodes tick at exactly the cadence the pricing assumed
##   (single source: SpellBalance.CHANNEL_TICKS);
## - behavioral: a single 烈光贯日 no longer deletes the boss.

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
	Weather.reset()

	# --- One-shot costs unchanged (the pricing refactor must not move them) ---
	_expect(_cost("火球术") == 20, "火球术 stays 20 (got %d)" % _cost("火球术"))
	_expect(_cost("落雷") == 27, "落雷 stays 27 (got %d)" % _cost("落雷"))
	_expect(_cost("烈焰焚天") == 30, "烈焰焚天 stays 30 (got %d)" % _cost("烈焰焚天"))
	_expect(_cost("守护之壁") == 14, "守护之壁 stays 14 (got %d)" % _cost("守护之壁"))

	# --- Potential ticks: duration buys exactly what it can land ---
	_expect(SpellBalance.potential_ticks(_craft("beam", 18.0, 1.2)) == 3,
			"beam 1.2s = 3 ticks (0.4s cadence)")
	_expect(SpellBalance.potential_ticks(_craft("field", 8.0, 2.5)) == 5,
			"field 2.5s = 5 ticks (0.5s cadence)")
	_expect(SpellBalance.potential_ticks(_craft("summon", 8.0, 4.0)) == 4,
			"summon 4s = 4 zaps (1.0s cadence)")
	_expect(SpellBalance.potential_ticks(_craft("tornado", 10.0, 4.0)) == 3,
			"tornado prices 3 ticks regardless of duration (push clears it)")
	_expect(SpellBalance.potential_ticks(_craft("projectile", 20.0, 2.0)) == 1,
			"one-shot shapes land once")

	# --- Registry ratio table: everything under the 2.0 ceiling ---
	print("---- balance table (damage-per-mana) ----")
	var worst := 0.0
	for name in LocalSpellRegistry.DRAFTS:
		var checked: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup(name))
		var cost: int = SpellBalance.compute_cost(checked["spell"])
		var ticks: int = maxi(SpellBalance.potential_ticks(checked["spell"]), 1)
		var potential: float = float(checked["spell"]["parameters"]["damage"]) * ticks
		var ratio: float = potential / float(cost) if cost > 0 else 0.0
		print("%-8s cost %2d  dmg %2.0f x%d = %3.0f  ratio %.2f"
				% [name, cost, float(checked["spell"]["parameters"]["damage"]), ticks,
				potential, ratio])
		worst = maxf(worst, ratio)
		_expect(ratio < 2.0, "%s under the 2.0 ceiling (%.2f)" % [name, ratio])
	print("------------------------------------------")

	# --- Max-clamped crafted spells: the ceiling holds at the extremes ---
	for shape in ["beam", "field", "summon", "tornado"]:
		var spell := _craft(shape, 60.0, 5.0)
		spell["parameters"]["radius"] = 160.0
		var cost: int = SpellBalance.compute_cost(SpellValidator.validate(spell)["spell"])
		var ticks: int = maxi(SpellBalance.potential_ticks(spell), 1)
		var ratio: float = 60.0 * ticks / float(cost)
		_expect(ratio < 2.0, "max-clamped %s stays under 2.0 (%.2f, cost %d)"
				% [shape, ratio, cost])
	var max_bolt := _craft("projectile", 60.0, 2.0)
	max_bolt["parameters"]["speed"] = 420.0
	var bolt_cost: int = SpellBalance.compute_cost(SpellValidator.validate(max_bolt)["spell"])
	_expect(60.0 / float(bolt_cost) < 2.0,
			"max-clamped projectile stays under 2.0 (%.2f)" % (60.0 / float(bolt_cost)))

	# --- Effects and pricing share one cadence (drift guard) ---
	var beam_fx: Area2D = load("res://scripts/effects/beam.gd").new()
	var summon_fx: Node2D = load("res://scripts/effects/summon.gd").new()
	_expect(absf(float(beam_fx.get("_tick_interval"))
				- SpellBalance.CHANNEL_TICKS["beam"]) < 0.0001,
			"beam ticks at the priced cadence")
	_expect(absf(float(summon_fx.get("_tick_interval"))
				- SpellBalance.CHANNEL_TICKS["summon"]) < 0.0001,
			"summon ticks at the priced cadence")
	beam_fx.free()
	summon_fx.free()
	_expect(SpellBalance.CHANNEL_TICKS["beam"] >= 0.3,
			"beam cadence stays slow enough to price (>= 0.3s)")

	# --- Behavioral: one beam no longer deletes the boss ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	player.hp = 9999.0
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame
	world.get_weather().force_state("clear")
	Weather.wind = Vector2.ZERO
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_right")
	var boss: CharacterBody2D = load("res://scenes/enemies/boss_slime.tscn").instantiate()
	boss.position = player.global_position + Vector2(150, 0)
	world.get_entity_parent().add_child(boss)
	await physics_frame
	var hp0: float = boss.hp
	var result: Dictionary = await MagicFacade.cast("烈光贯日", player, world, SpellSession.new())
	_expect(result["ok"], "beam casts against the boss")
	for i in 90:
		await physics_frame
		if not is_instance_valid(boss):
			break
	_expect(is_instance_valid(boss) and hp0 - boss.hp < 90.0,
			"one beam leaves the boss standing (dealt %.0f of 120)" % (hp0 - boss.hp if is_instance_valid(boss) else 120.0))
	world.free()
	Weather.reset()

	_teardown()


func _cost(name: String) -> int:
	var checked: Dictionary = SpellValidator.validate(LocalSpellRegistry.lookup(name))
	return SpellBalance.compute_cost(checked["spell"])


func _craft(shape: String, damage: float, duration: float) -> Dictionary:
	return {"display": shape, "element": "fire", "shape": shape,
			"mechanics": ["damage"],
			"parameters": {"damage": damage, "radius": 80.0, "speed": 0.0,
			"duration": duration}}


func _teardown() -> void:
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
