extends SceneTree
## Headless test for the offline casting pipeline: normalization,
## local registry, validation, balance and the facade end-to-end
## (including mana accounting and graceful unknown/not-unlocked paths).
##
##   godot --headless --path . -s res://tests/magic_pipeline_test.gd

var _failures := 0
## Isolation: casts here persist spell-cache entries — stash the dev's
## real cache and restore it at the end.
var _cache_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = TestIsolation.stash(TestIsolation.CACHE_PATH)
	SpellCache.reset()

	# --- Text normalization ---
	_expect(TextNormalizer.normalize("  火球术 ") == "火球术", "trims whitespace")
	_expect(TextNormalizer.normalize("火球术！") == "火球术", "strips punctuation")
	_expect(TextNormalizer.normalize("火球术！") == "火球术", "folds full-width marks")
	_expect(TextNormalizer.normalize("Ｆｉｒｅ９９") == "fire99", "folds full-width alnum")
	_expect(TextNormalizer.normalize("…") == "", "drops non-cjk symbols")

	# --- Registry ---
	_expect(not LocalSpellRegistry.lookup("火球术").is_empty(), "registry knows 火球术")
	_expect(LocalSpellRegistry.lookup("任意乱码").is_empty(), "unknown phrase returns empty")

	# --- Validator ---
	var good := SpellValidator.validate(LocalSpellRegistry.lookup("火球术"))
	_expect(good["valid"], "火球术 draft validates")
	var bad := {"element": "void", "shape": "blackhole", "mechanics": ["delete_save"], "parameters": {}}
	var checked := SpellValidator.validate(bad)
	_expect(not checked["valid"] and checked["errors"].size() >= 3, "unknown element/shape/mechanic rejected")
	var over := {"element": "fire", "shape": "projectile", "mechanics": ["damage"],
			"parameters": {"damage": 999.0, "radius": 999.0, "speed": 999.0, "duration": 99.0}}
	var clamped := SpellValidator.validate(over)
	_expect(clamped["valid"], "out-of-range params clamp instead of fail")
	_expect(clamped["spell"]["parameters"]["damage"] == 60.0, "damage clamped to cap")

	# --- Balance ---
	var cost: int = SpellBalance.compute_cost(good["spell"])
	_expect(cost >= 10 and cost <= 20, "火球术 cost in simple band (got %d)" % cost)
	var costly := SpellValidator.validate(LocalSpellRegistry.lookup("烈焰焚天"))
	var cost2: int = SpellBalance.compute_cost(costly["spell"])
	_expect(cost2 > 20, "烈焰焚天 costs more than simple spells (got %d)" % cost2)

	# --- Facade end-to-end with a real world + player ---
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	var session := SpellSession.new()
	var r1: Dictionary = await MagicFacade.cast("  火球术！", player, world, session)
	_expect(r1["ok"], "cast 火球术 succeeds (%s)" % r1["message"])
	_expect(absf(player.mana - (100.0 - r1["cost"])) < 0.01, "mana charged (left %.1f)" % player.mana)
	var projectiles := 0
	for child in world.get_entity_parent().get_children():
		if child is Area2D:
			projectiles += 1
	_expect(projectiles >= 1, "projectile spawned")
	_expect(session.codex.size() == 1, "successful cast recorded in codex")

	# Same spell again this adventure: duplicate, no mana charged.
	# (Normalized text matches the stored "火球术", so the normalized
	# check fires before the mechanism check.)
	var mana_after_r1: float = player.mana
	var rdup: Dictionary = await MagicFacade.cast("火球术", player, world, session)
	_expect(not rdup["ok"] and rdup["reason"] == "duplicate_normalized",
			"recast blocked as duplicate (%s)" % rdup["reason"])
	_expect(absf(player.mana - mana_after_r1) < 0.01, "duplicate charges no mana")

	var r2: Dictionary = await MagicFacade.cast("神秘乱语", player, world, session)
	_expect(not r2["ok"] and r2["reason"] == "unknown", "unknown phrase rejected gracefully")

	# Implemented non-projectile shape: executes and records like any
	# spell; a repeat is a mechanism duplicate, not not_unlocked.
	var r3: Dictionary = await MagicFacade.cast("风卷残云", player, world, session)
	_expect(r3["ok"], "tornado shape executes now (%s)" % r3["message"])
	var r3b: Dictionary = await MagicFacade.cast("风卷残云", player, world, session)
	_expect(not r3b["ok"] and r3b["reason"].begins_with("duplicate"),
			"implemented cast records as duplicate on retry (%s)" % r3b["reason"])
	_expect(session.codex.size() == 2, "codex holds projectile + tornado")

	# Shape outside the validator whitelist: rejected at validation
	# (before mana, before the executor), never recorded. The executor's
	# not_unlocked branch is now a pure defense-in-depth fallback.
	var dream_draft := LocalSpellRegistry.lookup("火球术").duplicate(true)
	dream_draft["shape"] = "dream"
	SpellCache.store("梦中咒", "梦中咒", dream_draft)
	var r4: Dictionary = await MagicFacade.cast("梦中咒", player, world, session)
	_expect(not r4["ok"] and r4["reason"] == "invalid",
			"whitelist-external shape rejected by the validator (%s)" % r4["reason"])
	var r4b: Dictionary = await MagicFacade.cast("梦中咒", player, world, session)
	_expect(not r4b["ok"] and r4b["reason"] == "invalid",
			"refused casts are not recorded as duplicates")
	_expect(session.codex.size() == 2, "codex unchanged by refused shape")

	# Low mana on a FRESH session so uniqueness does not mask the check.
	var fresh := SpellSession.new()
	var mana_before: float = player.mana
	player.mana = 3.0
	var r5: Dictionary = await MagicFacade.cast("火球术", player, world, fresh)
	_expect(not r5["ok"] and r5["reason"] == "no_mana", "low mana blocks cast")
	player.mana = mana_before

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
