extends SceneTree
## Headless test for the spell cache (Phase 5 offline half): SaveManager
## file semantics, unit store/lookup/reset/reload, facade integration
## with a REAL world+player, and the trust rules — a cache hit still
## passes validation, the session duplicate gate, and costs mana; a
## poisoned cache entry cannot bypass the validator.
##
##   godot --headless --path . -s res://tests/spell_cache_test.gd

var _failures := 0
## Isolation: back up / clear / restore the developer's real cache file.
var _cache_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cache_backup = ""
	if FileAccess.file_exists(SaveManager.SPELL_CACHE_PATH):
		var mf := FileAccess.open(SaveManager.SPELL_CACHE_PATH, FileAccess.READ)
		_cache_backup = mf.get_as_text()
		mf.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SPELL_CACHE_PATH))
	SpellCache.reset()

	# --- SaveManager tier: fresh / roundtrip / corrupt / version ---
	var fresh: Dictionary = SaveManager.load_spell_cache()
	_expect(fresh["ok"] and fresh["cache"].is_empty(),
			"missing cache file = cold cache, not an error")
	var sw: Dictionary = SaveManager.save_spell_cache(
			{"exact": {"火球术": {"display": "火球术"}}, "normalized": {}})
	_expect(sw["ok"], "cache save ok (%s)" % sw.get("error", ""))
	var lw: Dictionary = SaveManager.load_spell_cache()
	_expect(lw["ok"] and lw["cache"]["exact"].has("火球术"), "cache roundtrip preserves data")
	var cf := FileAccess.open(SaveManager.SPELL_CACHE_PATH, FileAccess.WRITE)
	cf.store_string("{ nope")
	cf.close()
	var bad: Dictionary = SaveManager.load_spell_cache()
	_expect(not bad["ok"] and bad["error"] == "corrupted spell cache",
			"corrupted cache refused safely")
	var vf := FileAccess.open(SaveManager.SPELL_CACHE_PATH, FileAccess.WRITE)
	vf.store_string(JSON.stringify({"version": 999, "cache": {}}))
	vf.close()
	var old: Dictionary = SaveManager.load_spell_cache()
	_expect(not old["ok"] and old["error"].begins_with("unsupported version"),
			"unknown cache version refused")

	# --- Unit: store/lookup under both keys, copy semantics, reset ---
	SpellCache.reset()
	SpellCache.store("火球术！", "火球术", {"display": "火球术", "element": "fire"})
	_expect(SpellCache.lookup_exact("火球术！").get("display", "") == "火球术",
			"exact key hit")
	_expect(SpellCache.lookup_normalized("火球术").get("display", "") == "火球术",
			"normalized key hit")
	_expect(SpellCache.lookup_exact("别的").is_empty()
			and SpellCache.lookup_normalized("别的").is_empty(), "miss on unknown keys")
	# Caller mutation must not poison the cache (deep-copy semantics).
	var grabbed: Dictionary = SpellCache.lookup_exact("火球术！")
	grabbed["element"] = "ice"
	_expect(SpellCache.lookup_exact("火球术！")["element"] == "fire",
			"returned draft is a copy")
	_expect(SpellCache.size() == 1, "size counts normalized entries")
	SpellCache.reset()
	_expect(SpellCache.lookup_exact("火球术！").is_empty(), "reset forgets in memory")
	SpellCache.reload_from_disk()
	_expect(SpellCache.lookup_exact("火球术！")["element"] == "fire",
			"reload_from_disk restores persisted cache")

	# --- Facade integration on a real world ---
	# Cold cache for the integration run: the unit block above stored
	# entries that would otherwise satisfy these casts from the cache.
	SpellCache.clear_persisted()
	var world: Node2D = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	world.get_entity_parent().add_child(player)
	await physics_frame
	await physics_frame

	var session := SpellSession.new()
	var r1: Dictionary = MagicFacade.cast("火球术", player, world, session)
	_expect(r1["ok"] and r1["source"] == "registry", "first cast comes from the registry")
	_expect(SpellCache.lookup_exact("火球术").get("display", "") == "火球术",
			"successful registry cast is cached")

	# Trust rule 1: a cache hit still hits the session duplicate gate.
	var r2: Dictionary = MagicFacade.cast("火球术", player, world, session)
	_expect(not r2["ok"] and r2["reason"].begins_with("duplicate"),
			"cached repeat still refused by session uniqueness (%s)" % r2["reason"])

	# Trust rule 2: cache hits still cost the same mana. The variant
	# text misses the exact table (raw key differs) and hits the
	# normalized one.
	var mana_before: float = player.mana
	var session2 := SpellSession.new()
	var r3: Dictionary = MagicFacade.cast(" 火球术！", player, world, session2)
	_expect(r3["ok"] and r3["source"] == "cache_normalized",
			"variant text hits the normalized cache (source=%s)" % r3["source"])
	var cost_paid: float = mana_before - player.mana
	_expect(absf(cost_paid - float(r3["cost"])) < 0.01 and r3["cost"] == 20,
			"cache hit charged the same 20 mana (paid %.0f)" % cost_paid)

	# Trust rule 3: a poisoned cache entry cannot bypass the validator.
	var session3 := SpellSession.new()
	SpellCache.store("毁天灭地", "毁天灭地", {"display": "毁天灭地", "element": "fire",
			"shape": "projectile", "mechanics": ["damage"],
			"parameters": {"damage": 9999, "radius": 8, "speed": 300, "duration": 2.0}})
	var r4: Dictionary = MagicFacade.cast("毁天灭地", player, world, session3)
	_expect(r4["ok"], "poisoned entry still casts (validator clamps, never rejects whole cache)")
	_expect(float(r4["spell"]["parameters"]["damage"]) <= 60.0,
			"clamped to the damage ceiling (got %.0f)" % float(r4["spell"]["parameters"]["damage"]))

	# Unknown text is never cached.
	SpellCache.reset()
	var r5: Dictionary = MagicFacade.cast("阿布拉卡达布拉", player, world, session3)
	_expect(not r5["ok"] and r5["reason"] == "unknown", "unknown spell refused")
	_expect(SpellCache.lookup_exact("阿布拉卡达布拉").is_empty()
			and SpellCache.size() == 0, "unknown text leaves no cache trace")

	# Simulated restart: cold memory, disk reload, still hits.
	SpellCache.reset()
	SpellCache.reload_from_disk()
	var session4 := SpellSession.new()
	var r6: Dictionary = MagicFacade.cast("火球术", player, world, session4)
	_expect(r6["ok"] and r6["source"] == "cache_exact", "after simulated restart the cache still hits")

	for child in root.get_children():
		child.free()
	if _cache_backup != "":
		var rf := FileAccess.open(SaveManager.SPELL_CACHE_PATH, FileAccess.WRITE)
		rf.store_string(_cache_backup)
		rf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SPELL_CACHE_PATH))
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
